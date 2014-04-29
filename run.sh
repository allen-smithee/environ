#!/bin/bash
set -e

CPU_COUNT=`cat /proc/cpuinfo | grep processor | wc -l`
RUN_PATH=`pwd`

# require sudo
if [ $EUID != 0 ]; then
    echo "Root access is required to continue..."
    sudo "$0" "$@"
    exit $?
fi

#
# Print script usage
#
function usage {
    cat << EOF
    usage: $0 options

    This script will install a standard Python and/or Node
    environment.

    OPTIONS:
      -s  Install standard build tools
      -p  Install Python packaging and common libs
      -n  Install Node packaging
      -v  Node Version (eg: v0.10.26)
EOF
}

#
# Wrap commands in tmp context 
#
function start_tmp {
    mkdir -p tmp
    pushd tmp
}

function end_tmp {
    popd
    rm -rf tmp
}

function clean_tmp {
    cd $RUN_PATH
    rm -rf tmp
    trap - EXIT INT TERM
    exit 1
}

#
# Standard build tools
#
function build_tools {
    apt-get update
    apt-get install -y build-essential
    apt-get install -y git
    apt-get install -y pkg-config
}

#
# Python build tools
#
function python_tools {
    apt-get install -y python3-setuptools
    apt-get install -y python3-minimal
    apt-get install -y python3-dev

    start_tmp
    wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py
    python3 get-pip.py
    end_tmp
}

#
# Standard Python libs
#
function python_libs {
    pip3 install -U decorator
    pip3 install -U autologging
}

#
# Node build tools
#
function node_tools {
    local node_version="$1"
    local node_url="http://nodejs.org/dist/${node_version}/node-${node_version}.tar.gz"
    echo $node_url

    start_tmp    
    wget $node_url
    tar -xvzf "node-${node_version}.tar.gz"
    pushd "node-${node_version}"
    ./configure
    make -j `expr $CPU_COUNT + 1`
    make install
    popd
    end_tmp
    
    start_tmp
    git clone git://github.com/isaacs/npm.git
    pushd npm
    make install
    popd
    end_tmp

    npm install -g grunt-cli
}


#
# Parse arguments
#

node_version="v0.10.26"
install_standard="no"
install_python="no"
install_node="no"

while getopts "spnv:" opt; do
    case $opt in
        s)
            install_standard="yes"
            ;;
        v)
            node_version=$opt
            ;;
        n)
            install_node="yes"
            ;;
        p)
            install_python="yes"
            ;;
        \?)
            usage
            exit 1
            ;;
    esac
done

#
# Run Actions
#
trap clean_tmp EXIT INT TERM

if [ $install_standard == "yes" ]; then
    build_tools;
fi

if [ $install_python == "yes" ]; then
    python_tools
    python_libs;
fi

if [ $install_node == "yes" ]; then
    node_tools $node_version;
fi

trap - EXIT INT TERM
exit 0

