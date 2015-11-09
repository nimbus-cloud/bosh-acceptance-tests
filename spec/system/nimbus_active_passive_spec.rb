require 'system/spec_helper'

describe 'nimbus' do

  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  def deploy_hem(passive, first_time_deployment = false)
    reload_deployment_spec
    use_deployment_name('bat-hem')
    use_static_ip
    set_nimbus_static_ip(first_static_ip) # 10.76.247.240
    use_persistent_disk(1024)
    if passive
      passive_side
    else
      active_side(first_time_deployment)
    end
    @first_deployment_result = @requirements.requirement(deployment, @spec, force: true)
  end

  def deploy_slo(passive, first_time_deployment = false)
    reload_deployment_spec
    use_deployment_name('bat-slo')
    use_static_ip
    set_nimbus_static_ip(second_static_ip) # 10.76.247.241
    use_persistent_disk(1024)
    if passive
      passive_side
    else
      active_side(first_time_deployment)
    end
    @second_deployment_result = @requirements.requirement(deployment, @spec, force: true)
  end


  context '2 active/passive vms with drbd replication and dns updates' do

    before(:all) do
      deploy_slo(true)
      deploy_hem(false, true) # first time deployment - needs --force flag
      # TODO: drbd setup looses job_name folder from /var/vcap/store ???
      ssh_sudo(first_static_ip, 'vcap', 'mkdir /var/vcap/store/bat', ssh_options)
      ssh_sudo(first_static_ip, 'vcap', 'chown -R vcap:vcap /var/vcap/store/bat', ssh_options)
    end

    after(:all) do
      expect(@bosh_runner.bosh_safe('delete deployment bat-slo')).to succeed
      expect(@bosh_runner.bosh_safe('delete deployment bat-hem --force')).to succeed # need --force as drbd unmount checks if both sides are in sync before unmounting
    end

    it 'hem vm registers its ip under bat-test.data.test-01.test-paas.bskyb.com name' do
      current_ip = Resolv.getaddress 'bat-test.data.test-01.test-paas.bskyb.com'
      expect(current_ip).to eq(first_static_ip)
    end

    it 'sets up drbd primary on hem and drbd secondary on slo', ssh: true do
      sleep(8)
      expect(ssh(first_static_ip, 'vcap', 'cat /proc/drbd', ssh_options)).to include '1: cs:Connected ro:Primary/Secondary ds:UpToDate/UpToDate A r-----'
      expect(ssh(second_static_ip, 'vcap', 'cat /proc/drbd', ssh_options)).to include '1: cs:Connected ro:Secondary/Primary ds:UpToDate/UpToDate A r-----'
    end

    it 'replicates data under /var/vcap/store from hem side to slo side', ssh: true do
      # create file
      ssh(first_static_ip, 'vcap', "echo 'hem -> slo' > /var/vcap/store/bat/drbd_test", ssh_options)

      # cut-over
      deploy_hem(true)
      deploy_slo(false)

      # check file on the other side
      expect(ssh(second_static_ip, 'vcap', 'cat /var/vcap/store/bat/drbd_test', ssh_options).strip!).to eq 'hem -> slo'

      # ip
      current_ip = Resolv.getaddress 'bat-test.data.test-01.test-paas.bskyb.com'
      expect(current_ip).to eq(second_static_ip)

      # check drbd status
      sleep(8)
      expect(ssh(second_static_ip, 'vcap', 'cat /proc/drbd', ssh_options)).to include '1: cs:Connected ro:Primary/Secondary ds:UpToDate/UpToDate A r-----'
      expect(ssh(first_static_ip, 'vcap', 'cat /proc/drbd', ssh_options)).to include '1: cs:Connected ro:Secondary/Primary ds:UpToDate/UpToDate A r-----'
    end

    it 'replicates data under /var/vcap/store from slo side to hem side', ssh: true do
      # append
      ssh(second_static_ip, 'vcap', "echo 'slo -> hem' >> /var/vcap/store/bat/drbd_test", ssh_options)

      # cutover
      deploy_slo(true)
      deploy_hem(false)

      # check on the other side
      expect(ssh(first_static_ip, 'vcap', 'cat /var/vcap/store/bat/drbd_test', ssh_options).strip!).to eq "hem -> slo\nslo -> hem"

      # ip
      current_ip = Resolv.getaddress 'bat-test.data.test-01.test-paas.bskyb.com'
      expect(current_ip).to eq(first_static_ip)

      # check drbd status
      sleep(8)
      expect(ssh(first_static_ip, 'vcap', 'cat /proc/drbd', ssh_options)).to include '1: cs:Connected ro:Primary/Secondary ds:UpToDate/UpToDate A r-----'
      expect(ssh(second_static_ip, 'vcap', 'cat /proc/drbd', ssh_options)).to include '1: cs:Connected ro:Secondary/Primary ds:UpToDate/UpToDate A r-----'
    end

  end
end
