#
# This is a Vagrantfile to automatically provision a test environment
#
# See http://www.vagrantup.com/ for info on Vagrant.
#

# Settings common to all VMs
common_vm_settings = Proc.new do |vm|
  vm.customize ['modifyvm', :id, '--nictype2', '82543GC']
  vm.customize ['modifyvm', :id, '--largepages', 'on']
  vm.customize ['modifyvm', :id, '--nestedpaging', 'on']
  vm.customize ['modifyvm', :id, '--vtxvpid', 'on']
  vm.customize ['modifyvm', :id, '--hwvirtex', 'on']
  vm.customize ['modifyvm', :id, '--ioapic', 'on']
end

test_memory = ENV['TEST_VM_MEM'] || (15 * 1024).to_s
test_cpus = ENV['TEST_VM_CPUs'] || '5'

# Settings common to all test VMs
common_test_vm_settings = Proc.new do |testvm|
  # starting screen wants a tty; for more see https://github.com/hashicorp/vagrant/issues/1673
  testvm.ssh.pty = true
  testvm.vm.provision :shell, privileged: false, name: 'Run Ratis Servers', inline: <<-EOH
    pkill -u vagrant -f ratis || true
    # divide 95% of the VM memory in to thirds for the servers
    export JAVA_OPTS="-Xmx #{(test_memory.to_i * 0.95) / 3}"
    script -c "screen -c /vagrant/screenrcs/ratis_$(hostname)_screenrc" /dev/stdout
  EOH
  testvm.ssh.pty = false

  # forward the ports to the host
  testvm.vm.network 'forwarded_port', guest: 6000, host: 6000, host_ip: '127.0.0.1', id: 'RatisServer1'
  testvm.vm.network 'forwarded_port', guest: 6001, host: 6001, host_ip: '127.0.0.1', id: 'RatisServer2'
  testvm.vm.network 'forwarded_port', guest: 6002, host: 6002, host_ip: '127.0.0.1', id: 'RatisServer3'

  testvm.vm.box = 'ratistest'
  testvm.vm.box_url = 'ratistest.box'

  testvm.vm.provider :virtualbox do |vb|
    vb.gui = false
    vb.customize ['modifyvm', :id, '--memory', test_memory]
    vb.customize ['modifyvm', :id, '--cpus', test_cpus]
    common_vm_settings.call(vb)
  end
end

Vagrant.configure('2') do |config|
  config.vm.define :ratisbuild do |ratisbuild|
    ratisbuild.vm.hostname = "ratis-build"
    # setup a local Maven settings.xml if available
    if File.exist?(File.expand_path('~/.m2/settings.xml'))
      config.vm.provision 'shell', privileged: false, inline: <<-EOM.gsub(/^\s+/, '').strip
        mkdir -p ~/.m2
      EOM

      config.vm.provision 'file', source: '~/.m2/settings.xml',
                                  destination: '/home/vagrant/.m2/settings.xml'
    end

    # install packages
    ratisbuild.vm.provision :shell, name: 'Install Packages', inline: <<-EOH
      set -e
      # setup /usr/local/bin for non-packaged software
      if [[ $(egrep -c 'PATH.*/usr/local/bin' /etc/environment) -eq 0 ]]; then
        echo 'export PATH=${PATH}:/usr/local/bin' >> /etc/environment
      fi

      # only install Java if we have not before
      if [[ $(dpkg-query -W -f='${Status}' oracle-java8-installer 2>/dev/null | grep -c 'install ok installed') -ne 1 ]]; then
        echo 'debconf shared/accepted-oracle-license-v1-1 select true' | debconf-set-selections
        echo 'debconf shared/accepted-oracle-license-v1-1 seen true' | debconf-set-selections
        add-apt-repository -y ppa:webupd8team/java
        apt-get update
        apt-get -y install oracle-java8-installer oracle-java8-set-default
      fi

      # install Maven
      mkdir -p /usr/local
      wget --continue http://apache.mirrors.ionfish.org/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz
      tar -xzf apache-maven-3.6.0-bin.tar.gz -C /usr/local
      [ -L /usr/local/bin/mvn ] || ln -s /usr/local/apache-maven-3.6.0/bin/mvn /usr/local/bin/mvn

      # Namazu Dependencies
      apt-get install -y git libnetfilter-queue-dev libzmq3-dev
      wget --continue https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz
      tar -xzf go1.11.2.linux-amd64.tar.gz -C /usr/local
      [ -L /usr/local/bin/go ] || ln -s /usr/local/go/bin/go /usr/local/bin/go
    EOH

    # download and build Namazu
    ratisbuild.vm.provision :shell, privileged: false, name: 'Build Namazu', inline: <<-EOH
      set -e
      cd ~/
      [ '!' -d namazu ] && git clone https://github.com/osrg/namazu
      cd namazu
      export GOROOT=/usr/local/go
      export GOPATH=`pwd`
      # for some reason seelog fails to pull automatically
      go get -u github.com/cihub/seelog
      ./build
    EOH

    # download and build Ratis
    ratisbuild.vm.provision :shell, privileged: false, name: 'Build Ratis', inline: <<-EOH
      set -e
      cd ~/
      # load proxies or other environment specifics loaded via a Vagrantfile.local
      # or otherwise into /etc/environment
      . /etc/environment
      [ '!' -d incubator-ratis ] && git clone https://github.com/apache/incubator-ratis
      cd incubator-ratis
      mvn package -DskipTests
    EOH

    build_memory = ENV['BUILD_VM_MEM'] || (2 * 1024).to_s
    build_cpus = ENV['BUILD_VM_CPUs'] || '1'
   
    ratisbuild.vm.provider :virtualbox do |vb|
      vb.gui = false
      vb.name = ratisbuild.vm.hostname
      vb.customize ['modifyvm', :id, '--memory', build_memory]
      vb.customize ['modifyvm', :id, '--cpus', build_cpus]
      common_vm_settings.call(vb)
    end

    ratisbuild.vm.box = 'ubuntu/bionic64'
  end

  # Configure a generic VM with three Ratis servers
  config.vm.define :ratisservers do |server|
    server.vm.hostname = "ratis-server"
    motd = %(Welcome to the Ratis test VM
             ========================================
             This VM provides the following:
             * screen -x -- this will connect you to a GNU Screen session running all three Ratis daemons
             * clean-up and restart on your hypervisor with: vagrant up --provision ratisserver
             ========================================
            )
    server.vm.provision :shell, name: 'Update MOTD', inline: <<-EOH.gsub(/^\s+/, '').strip
      set -e
      cat <<EOF >/etc/motd
      #{motd.gsub(/^\s+/, ' ').strip}
      EOF
    EOH

    # normal test VM spin-up steps
    common_test_vm_settings.call(server)
    server.vm.provider :virtualbox do |vb|
      vb.name = server.vm.hostname
    end
  end

  # Configure a pathological VM with three Ratis servers running on bad disks
  config.vm.define :ratishddslowdown do |hdd|
    hdd.vm.hostname = "ratis-slowhdd"
    motd = %(Welcome to the Ratis flakey disk test VM
             ========================================
             This VM provides the following:
             * screen -x -- this will connect you to a GNU Screen session running all three Ratis daemons
             * sudo screen -x -- this will connect you to a GNU Screen session running the Namazu fuzzing daemon
             * clean-up and restart on your hypervisor with: vagrant up --provision ratishddslowdown
             ========================================
            )

    hdd.vm.provision :shell, name: 'Update MOTD', inline: <<-EOH.gsub(/^\s+/, '').strip
      cat <<EOF >/etc/motd
      #{motd.gsub(/^\s+/, ' ').strip}
      EOF
    EOH

    hdd.vm.provision :shell, name: 'Prepare Namazu Daemon', inline: <<-EOH
      set -e
      mkdir -p /tmp/data{0,0_slowed,1,1_slowed,2,2_slowed}
      chown vagrant /tmp/data{0,0_slowed,1,1_slowed,2,2_slowed}
      pkill -u root -f namazu || true
      fusermount -u /tmp/data0_slowed/ || true
      fusermount -u /tmp/data1_slowed/ || true
      fusermount -u /tmp/data2_slowed/ || true
    EOH

    hdd.ssh.pty = true
    hdd.vm.provision :shell, name: 'Run Namazu Daemon', inline: <<-EOH
      script -c 'screen -c /vagrant/screenrcs/namazu_hdd_screenrc' /dev/stdout
    EOH
    hdd.ssh.pty = false

    # normal test VM spin-up steps
    common_test_vm_settings.call(hdd)
    hdd.vm.provider :virtualbox do |vb|
      vb.name = hdd.vm.hostname
    end
  end
end
