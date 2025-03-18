#!/usr/bin/env zsh

OS=$(uname)

# This script is idempotent and will restore your local setup to the same state even if run multiple times.
# In most cases, the script will provide warning messages if skipping certain steps. Each such message will be useful to give you a hint about what to do to force rerunning of that step.

is_non_zero_string() {
	! test -z "${1}"
}

is_directory() {
	is_non_zero_string "${1}" && test -d "${1}"
}

script_start_time=$(date +%s)
echo "==> Script started at: $(date)"

DOTFILES_DIR="$HOME/projects/dotfiles"

#############################################################
# Utility funcs used only within this script #
#############################################################

section_header() {
  echo "$(blue '==>') $(purple "${1}")"
}

keep_sudo_alive() {
	section_header 'Keeping sudo alive till this script has finished'
	sudo -v
	while true; do
		sudo -n true
		sleep 60
		kill -0 "$$" || exit
	done 2>/dev/null &
}

###############################################################################################
# Ask for the administrator password upfront and keep it alive until this script has finished #
###############################################################################################

keep_sudo_alive()

###############################
# Do not allow rootless login #
###############################
# Note: Commented out since I am not sure if we need to do this on the office MBP or not
# section_header 'Verifying rootless status'
# [[ "$(/usr/bin/csrutil status | awk '/status/ {print $5}' | sed 's/\.$//')" == "enabled" ]] && error "csrutil ('rootless') is enabled. Please disable in boot screen and run again!"

##################################
# Install command line dev tools #
##################################
if [[ $OS == Darwin ]]; then
  section_header 'Installing xcode command-line tools'
  if ! is_directory '/Library/Developer/CommandLineTools/usr/bin'; then
    # install using the non-gui cmd-line alone
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    sudo softwareupdate -ia --agree-to-license --force
    rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    success 'Successfully installed xcode command-line tools'
  else
    warn 'skipping installation of xcode command-line tools since its already present'
  fi
fi

####################
# Install dotfiles #
####################
section_header "Installing dotfiles into '$(yellow "${DOTFILES_DIR}")'"
if is_non_zero_string "${DOTFILES_DIR}" && ! is_directory "${DOTFILES_DIR}"; then
	
	# Delete the auto-generated .zshrc since that needs to be replaced by the one in the DOTFILES_DIR repo
	rm -rf "${HOME}/.zshrc"

	# Note: Cloning with https since the ssh keys will not be present at this time
	clone_repo_into "https://github.com/jondum/dotfiles" "${DOTFILES_DIR}"

else
	warn "skipping cloning the dotfiles repo since '${DOTFILES_DIR}' is either not defined or is already a git repo"
fi

# Grab rest of env vars and config
source "${DOTFILES_DIR}/packages/shell/.zshenv"

#################################################################################
# Ensure that some of the directories corresponding to the env vars are created #
#################################################################################
section_header 'Creating directories defined by various env vars'
ensure_dir_exists "${DOTFILES_DIR}"
ensure_dir_exists "${PROJECTS_BASE_DIR}"
ensure_dir_exists "${PERSONAL_BIN_DIR}"
ensure_dir_exists "${XDG_CACHE_HOME}"
ensure_dir_exists "${XDG_CONFIG_HOME}"
ensure_dir_exists "${XDG_DATA_HOME}"
ensure_dir_exists "${XDG_STATE_HOME}"

ensure_dir_exists "${XDG_CONFIG_HOME}/zsh"
touch $HISTFILE

############################
# Disable macos gatekeeper #
############################
# section_header 'Disabling macos gatekeeper'
# sudo spectl --master-disable

##############################
# Install custom omz plugins #
##############################
# Note: Some of these are available via brew, but enabling them will take an additional step and the only other benefit (of keeping them up-to-date using brew can still be achieved by updating the git repos directly)
section_header 'Installing custom omz plugins'
# Note: These are not installed using homebrew since sourcing of the files needs to be explicit in .zshrc
# Also, the order of these being referenced in the zsh session startup (for vanilla OS) will cause a warning to be printed though the rest of the shell startup sequence is still performed. Ultimately, until they become included by default into omz, keep them here as custom plugins

! is_non_zero_string "${HOMEBREW_PREFIX}" && error "'HOMEBREW_PREFIX' env var is not set; something is wrong. Please correct before retrying!"

# Load all zsh config files for PATH and other env vars to take effect
FIRST_INSTALL=true load_zsh_configs

####################
# Install homebrew #
####################
if [[ $OS == Darwin ]]; then

  section_header "Installing homebrew into '$(yellow "${HOMEBREW_PREFIX}")'"
  if ! command_exists brew; then
    # Prep for installing homebrew
    sudo mkdir -p "${HOMEBREW_PREFIX}/tmp" "${HOMEBREW_PREFIX}/repository" "${HOMEBREW_PREFIX}/plugins" "${HOMEBREW_PREFIX}/bin"
    sudo chown -fR "$(whoami)":admin "${HOMEBREW_PREFIX}"
    chmod u+w "${HOMEBREW_PREFIX}"

    NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    success 'Successfully installed homebrew'

    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
  else
    warn "skipping installation of homebrew since it's already installed"
  fi

  # TODO: Need to investigate why this step exits on a vanilla OS's first run of this script
  # Note: Do not set the 'HOMEBREW_BASE_INSTALL' in this script - since its supposed to run idempotently. Also, don't run the cleanup of pre-installed brews/casks (for the same reason)
  brew bundle check || brew bundle || true
  success 'Successfully installed cmd-line and gui apps using homebrew'

fi

if [[ $OS == Linux ]]; then

  sudo apt install -y \
    avahi-daemon \
    g++ \
    make \
    git-lfs \
    stow \
    ffmpeg \
    eza \ 
    bat \
    fzf \
    jq \
    ripgrep \
    libpq-dev \
    httpie \
    lua \
    llvm \
    neovim \
    watchman \
    rustup \
    zsh \

fi


# Note: Load all zsh config files for the 2nd time for PATH and other env vars to take effect (due to defensive programming)
load_zsh_configs

section_header 'Installing node'
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
nvm install node

section_header 'Installing python'
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install


###################################################################
# Restore the preferences from the older machine into the new one #
###################################################################
#
# section_header 'Restore preferences'
# if command_exists 'osx-defaults.sh'; then
#   osx-defaults.sh -s
#   success 'Successfully baselines preferences'
# else
#   warn "skipping baselining of preferences since 'osx-defaults.sh' couldn't be found in the PATH; Please baseline manually and follow it up with re-import of the backed-up preferences"
# fi
#
# if command_exists 'capture-defaults.sh'; then
#   capture-defaults.sh i
#   success 'Successfully restored preferences from backup'
# else
#   warn "skipping importing of preferences since 'capture-defaults.sh' couldn't be found in the PATH; Please set it up manually"
# fi

################################
# Recreate the zsh completions #
################################
section_header 'Recreate zsh completions'
rm -rf "${XDG_CACHE_HOME}/zcompdump-${ZSH_VERSION}"
autoload -Uz compinit && compinit -C -d "${XDG_CACHE_HOME}/zcompdump-${ZSH_VERSION}"

#################################
# Setup ssh scripts/directories #
#################################
section_header 'Setting ssh config file permissions'
set_ssh_folder_permissions

###################
# Setup cron jobs #
###################
section_header 'Setup cron jobs'
if command_exists recron; then
	recron
	success 'Successfully setup cron jobs'
else
	warn "skipping setting up of cron jobs since 'recron' couldn't be found in the PATH; Please set it up manually"
fi

###############################
# Cleanup temp functions, etc #
###############################
# unfunction clone_omz_plugin_if_not_present

echo "\n"
success '** Finished auto installation process: MANUALLY QUIT AND RESTART iTerm2 and Terminal apps **'
echo "$(yellow "Remember to set the 'RAYCAST_SETTINGS_PASSWORD' env var, and then run the 'capture-raycast-configs.sh' script to import your Raycast configuration into the new machine.")"

script_end_time=$(date +%s)
echo "==> Script completed at: $(date)"
echo "==> Total execution time: $((script_end_time - script_start_time)) seconds"
