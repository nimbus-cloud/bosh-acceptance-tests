require 'system/spec_helper'

describe 'nimbus active/passive drbd and dns updates stuff' do

  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  context '2 active/passive vms with drbd replication and dns updates' do

    before(:all) do
      reload_deployment_spec
      # using password 'foobar'
      use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
      @our_ssh_options = ssh_options.merge(password: 'foobar')

      # first vm
      use_static_ip         # 10.76.247.240
      use_deployment_name('nimbus-passive')
      use_persistent_disk(1024)
      @first_deployment_result = @requirements.requirement(deployment, @spec)

      # second vm
      use_second_static_ip  # 10.76.247.241
      use_deployment_name('nimbus-active')
      use_persistent_disk(1024)
      @second_deployment_result = @requirements.requirement(deployment, @spec, force: true)
    end

    after(:all) do
      @requirements.cleanup(deployment)
    end

    it 'should set vcap password', ssh: true do
      # some ssh checks stuff
      expect(ssh_sudo(public_ip, 'vcap', 'whoami', @our_ssh_options)).to eq("root\n")
      expect(persistent_disk(public_ip, 'vcap', @our_ssh_options)).to_not eq(@size)
      expect(ssh(public_ip, 'vcap', "cat #{SAVE_FILE}", @our_ssh_options)).to match /foobar/
    end


  end
end
