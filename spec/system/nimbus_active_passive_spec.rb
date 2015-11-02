require 'system/spec_helper'

describe 'nimbus active/passive drbd and dns updates stuff' do

  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  context '2 active/passive vms with drbd replication and dns updates' do

    before(:all) do
      # secondary vm
      reload_deployment_spec
      use_second_static_ip  # 10.76.247.241
      use_deployment_name('bat-slo')
      use_persistent_disk(1024)
      passive_side
      @second_deployment_result = @requirements.requirement(deployment, @spec) #, force: true

      # primary vm
      reload_deployment_spec
      use_static_ip         # 10.76.247.240
      use_deployment_name('bat-hem')
      use_persistent_disk(1024)
      active_side
      @first_deployment_result = @requirements.requirement(deployment, @spec)
    end

    after(:all) do
      # @requirements.cleanup(deployment)
    end

    it 'should set vcap password', ssh: true do
      puts 'First deployment'
      puts @first_deployment_result

      puts 'Second deployment'
      puts @second_deployment_result

      # some ssh checks stuff
      # expect(ssh_sudo(public_ip, 'vcap', 'whoami', @our_ssh_options)).to eq("root\n")
      # expect(persistent_disk(public_ip, 'vcap', @our_ssh_options)).to_not eq(@size)
      # expect(ssh(public_ip, 'vcap', "cat #{SAVE_FILE}", @our_ssh_options)).to match /foobar/
    end


  end
end
