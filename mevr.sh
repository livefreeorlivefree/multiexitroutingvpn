#!/bin/bash

function bootstrap_load_environment
{
     if [[ -f merv/vars/environment.sh ]]
     then
        . merv/vars/./environment.sh
     fi
     if [[ -f vars/environment.sh ]]
     then
        . vars/./environment.sh
     fi
     if [[ -f merv/environment.sh ]]
     then
        . merv/./environment.sh
     fi
     if [[ -f environment.sh ]]
     then
        . ./environment.sh
     fi
}

function bootstrap_load_module()
{
    if [[ $SCRIPT_DIR == '' ]]
    then
        bootstrap_load_environment
    fi

    . $SCRIPT_DIR/modules/$1

    if [[ $? -ne 0 ]]
    then
        echo "Error loading module $1"
        return 1
    fi
}

bootstrap_load_module dependencies
bootstrap_load_module merv

# run.
merv_main $1 $2 $3
