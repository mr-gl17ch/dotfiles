#!/bin/bash
USER=$(who | awk '{print $1}' | head -n1)
HOME="/home/$USER"
DOTFILES="res"
DISTRO=`cat /etc/os-release | grep -v VERSION | grep ID | awk -F '=' '{print $2}'`
declare -a PM_PACKAGES=("zsh" "tmux" "vim")
declare -a CARGO_PACKAGES=("lsd")
source src/zsh-plug.sh
source src/nodejs.sh
source src/nvim.sh


good(){
    printf "\033[92;1mOK: $1\033[0m\n"
}
msg(){
    printf "\033[1m-->>: $1\033[0m\n"
}

warn(){
    printf >&2 "\033[93;1mWARNING: $1\033[0m\n"
}
error(){
    printf >&2 "\033[91;1mERROR: $1\033[0m\n"
}
 
usage() { 
    cat 1>&2 <<EOF
USAGE:
    ./runme.sh [FLAGS] 

FLAGS:
    -c, --configure         Configure dotfiles in correct places
    -i, --install           Install specified software
    -h, --help              Prints help information

EOF
}
 

check_location(){
    basename="$(dirname $0)"
    realpath="$(realpath $basename)"
    if [[ $realpath -ne $PWD ]];then
        error "need to be in the script directory to run script"
        return 1
    fi
    return 0
}
check_internet(){
    tool=ping
    msg "checking internet connection..."
    if ! $tool -c 4 8.8.8.8 2>/dev/null 1>&2; then
        error "not connected to the internet"
        return 1
    else 
        good "internet connection working"
    fi
}
config_packageman(){
    case $DISTRO in
        arch | manjaro)
            pm="pacman" 
            update="-Syy" 
            install="-S --noconfirm"
            ;;
        fedora | redhat | centos)
            pm="dnf"
            update="check-update" 
            install="install -y"
            ;;
        debian | ubuntu | kali | raspian | zorin | linuxmint | parrot | popos)
            pm="apt"
            update="update" 
            install="install -y"
            ;;
        void)
            pm="xbps-install"
            install=""
            update="-S"
	    ;;
        *)
            warn "could not identify DISTRO, running script as if it's debian based"
            if  apt -v 2>/dev/null 1&>2; then
                pm="apt"
                update="update"
                install="install -y"
            else
                warn "apt could not be detected, please edit the code to install $software using your package manager"
                return 1
            fi
            ;;
    esac
    return 0
}
packages_update(){
    msg "updating $DISTRO repositories"
    if $pm $update 2>/dev/null 1>&2; then
        good "repositories updated"
    else
        error "repositories failed to be updated run '$pm $update' to find out why"
        return 1
    fi
    return 0
}
package_install(){
    msg "installing $1..."
        if $pm $install $1 2>/dev/null 1>&2; then
            good "$1 installed"
        else
            error "$1 could not be installed run '$pm $install $1' to find out why" 
            return 1
        fi 
    return 0
}
install_software(){
    mkdir /opt 2>/dev/null 
    packages_update
    for i in "${PM_PACKAGES[@]}"
    do
        package_install $i
    done
    #install_nodejs
    #install_nvim
    if zsh --version 2>/dev/null 1>&2; then
        install_zsh-plug
    fi
    msg "installing starship prompt..."
    if sh -c "$(curl -fssl https://starship.rs/install.sh)" -- -y 2>/dev/null 1>&2;then 
        good "starship installed"
    else
        error "starship failed to install"
    fi
    msg "installing rust..."
    if sh -c "$(curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf)" -- -y 2>/dev/null 1>&2;then
        good "rust installed"
    else
        error "rust failed to install"
    fi

}
copy_files(){
    msg "copying $1 to $2"
    if [ -d $1 ]; then
        if cp -TR $1 $2 2>/dev/null ;then
            good "copied $1 to $2"
            chown -R $USER:$USER $2 
        else
            error "failed to copy $1 to $2"
        fi
    else
        if cp $1 $2 2>/dev/null ;then
            good "copied $1 to $2"
            chown -R $USER:$USER $2 
        else
            error "failed to copy $1 to $2"
        fi
    fi
}
configure(){
    cd $DOTFILES
    copy_files .zshrc $HOME
    copy_files starship.toml $HOME/.config
    copy_files .profile $HOME
    copy_files .vimrc $HOME
    copy_files .tmux.conf $HOME
    copy_files nvim $HOME/.config/nvim
    copy_files i3 $HOME/.config/i3
    copy_files polybar $HOME/.config/polybar
    copy_files fish $HOME/.config/fish
    copy_files kitty $HOME/.config/kitty
    cd ..
	return 0;
}
main(){
    if [[ $# -gt 0 ]]; then
        for arg in $@; do
            case $arg in
                -c|--configure)
                    configure
                    ;;
                -f|--install)
                    if [ $EUID -eq 0 ];then
                        if check_location; then
                            config_packageman
                        else
                            exit 1
                        fi
                        if check_internet;then
                            install_software
                        fi
                    else
                        error "must be root to install... exiting..."
                        exit 1
                    fi
                    ;;
                -h|--help|*)
                    usage
                    exit 0
                    ;;
            esac
        done
    else 
        usage
        exit 0
    fi
}
main $@
