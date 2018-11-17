# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# This is a Vagrantfile to automatically provision a test environment
#
# See http://www.vagrantup.com/ for info on Vagrant.
#

common_vm_settings = Proc.new do |vm|
  vm.customize ['modifyvm', :id, '--nictype2', '82543GC']
  vm.customize ['modifyvm', :id, '--largepages', 'on']
  vm.customize ['modifyvm', :id, '--nestedpaging', 'on']
  vm.customize ['modifyvm', :id, '--vtxvpid', 'on']
  vm.customize ['modifyvm', :id, '--hwvirtex', 'on']
  vm.customize ['modifyvm', :id, '--ioapic', 'on']
end

Vagrant.configure('2') do |config|
  config.vm.define :ratistest, primary: true do |ratistest|
    # install packages
    ratistest.vm.provision :shell, privileged: true, name: "Install Packages", inline: <<-EOH
      set -e
      # only install Java if we have not before
      if [[ $(dpkg-query -W -f='${Status}' oracle-java8-installer 2>/dev/null | grep -c 'install ok installed') -ne 1 ]]; then
        echo "debconf shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections 
        echo "debconf shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections
        add-apt-repository -y ppa:webupd8team/java
        apt-get update
        apt-get -y install oracle-java8-installer oracle-java8-set-default
      fi
      apt-get install -y git libnetfilter-queue-dev libzmq3-dev

      if [[ $(egrep -c "PATH.*/usr/local/bin" /etc/environment) -eq 0 ]]; then
        echo "export PATH=${PATH}:/usr/local/bin" >> /etc/environment
      fi
      mkdir -p /usr/local
      wget --continue http://apache.mirrors.ionfish.org/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz
      tar -xzf apache-maven-3.6.0-bin.tar.gz -C /usr/local
      [ -L /usr/local/bin/mvn ] || ln -s /usr/local/apache-maven-3.6.0/bin/mvn /usr/local/bin/mvn

      wget --continue https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz
      tar -xzf go1.11.2.linux-amd64.tar.gz -C /usr/local
      [ -L /usr/local/bin/go ] || ln -s /usr/local/go/bin/go /usr/local/bin/go
    EOH

    # download and build Namazu
    ratistest.vm.provision :shell, privileged: false, name: "Build Namazu", inline: <<-EOH
      set -e
      cd ~/
      [ '!' -d namazu ] && git clone https://github.com/osrg/namazu
      cd namazu
      export GOROOT=/usr/local/go
      export GOPATH=`pwd`
      # for some reason seelog fails to pull automatically
      go get -u github.com/cihub/seelog
      ./build
      if [[ $(egrep -c "PATH.*$(pwd)/namazu/bin" /etc/environment) -eq 0 ]]; then
        echo "export PATH=${PATH}:$(pwd)/namazu/bin" >> /etc/environment
      fi
    EOH

    # download and build Ratis
    ratistest.vm.provision :shell, privileged: false, name: "Build Ratis", inline: <<-EOH
      set -e
      cd ~/
      [ '!' -d incubator-ratis ] && git clone https://github.com/apache/incubator-ratis
      cd incubator-ratis
      mvn package -DskipTests
    EOH

    build_memory = ENV['TEST_VM_MEM'] || (2 * 1024).to_s
    build_cpus = ENV['TEST_VM_CPUs'] || '1'
   
    ratistest.vm.provider :virtualbox do |vb|
      vb.gui = false
      vb.name = 'ratis-test'
      common_vm_settings.call(vb)
    end

    ratistest.vm.box = 'ubuntu/bionic64'
  end

  config.vm.define :ratishddslowdown do |hdd|
    motd = %{Welcome to the Ratis flakey disk test VM
             ========================================
             This VM provides the following:
             * screen -x -- this will connect you to a GNU Screen session running all three Ratis daemons
             * sudo screen -x -- this will connect you to a GNU Screen session running the Namazu fuzzing daemon
             * clean-up and restart on your hypervisor with: vagrant up --provision ratishddslowdown
             ========================================
            }

    hdd.vm.provision :shell, privileged: true, name: "Run Namazu Daemon", inline: <<-EOH
      set -e
      cat <<EOF >/etc/motd
#{motd.gsub(/^\s+/, " ").strip}
EOF
      mkdir -p /tmp/data{0,1,2,2_slowed}
      chown vagrant /tmp/data{0,1,2,2_slowed}
      pkill -u root -f namazu || true
      fusermount -u /tmp/data2_slowed/ || true
      screen -dmS Namazu /home/vagrant/namazu/bin/nmz inspectors fs -original-dir /tmp/data2 -mount-point /tmp/data2_slowed/ -autopilot /vagrant/hdd_config.toml
    EOH

    # starting screen will want a tty; for more see https://github.com/hashicorp/vagrant/issues/1673
    hdd.ssh.pty = true
    hdd.vm.provision :shell, privileged: false, name: "Run Ratis Servers", inline: <<-EOH
      pkill -u vagrant -f ratis || true
      # divide 95% of the VM memory in to thirds for the servers
      export JAVA_OPTS="-Xmx #{(test_memory*0.95)/3}"
      screen -c /vagrant/screenrcs/ratis_screenrc
    EOH

    # forward the ports to the host
    hdd.vm.network "forwarded_port", guest: 6000, host: 6000, host_ip: "127.0.0.1", id: "RatisServer1"
    hdd.vm.network "forwarded_port", guest: 6001, host: 6001, host_ip: "127.0.0.1", id: "RatisServer2"
    hdd.vm.network "forwarded_port", guest: 6002, host: 6002, host_ip: "127.0.0.1", id: "RatisServer3"

    hdd.vm.box = 'ratistest'
    hdd.vm.box_url = 'ratistest.box'
    
    test_memory = ENV['TEST_VM_MEM'] || (15 * 1024).to_s
    test_cpus = ENV['TEST_VM_CPUs'] || '5'
   
    hdd.vm.provider :virtualbox do |vb|
      vb.gui = false
      vb.customize ['modifyvm', :id, '--memory', test_memory]
      vb.customize ['modifyvm', :id, '--cpus', test_cpus]
      common_vm_settings.call(vb)
    end
  end
end

