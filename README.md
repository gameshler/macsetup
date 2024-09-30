## My Mac Setup

This repo contains info on all the apps / tools / settings I use on my Mac.

- [Usage Instructions](#usage-instructions)
- [OS Settings](#os-settings)
  - [Desktop](#desktop)
  - [Finder](#finder)
  - [Dock](#dock)
- [Quick Launching](#quick-launching)
- [Homebrew](#homebrew)
  - [Homebrew](#homebrew-1)
- [Window Management](#window-management)
- [App Switching](#app-switching)
- [Other Apps I Use Daily](#other-apps-i-use-daily)
  - [Docker](#docker)
- [Terminal](#terminal)
  - [Shell](#shell)
    - [Load dotfiles](#load-dotfiles)
  - [Github SSH Setup](#github-ssh-setup)
    - [Other command line tools I use](#other-command-line-tools-i-use)
- [Node.js](#nodejs)
  - [Global Modules](#global-modules)

## Usage Instructions

clone the repository then cd into the repository(macsetup) and run ./setup.sh then follow through the script

## OS Settings

These are my preferred settings for `Desktop`, `Finder` and the `Dock`.

### Desktop

I don't like the new Desktop, Stage Manager or Widget features in Sonoma, so I disable them.

- System Preferences
  - Desktop & Dock
    - Desktop & Stage Manager
      - Show Items
        - On Desktop -> uncheck
        - In Stage Manager -> uncheck
      - Click wallpaper to reveal desktop -> Only in Stage Manager
      - Stage Manager -> uncheck
      - Widgets
        - On Desktop -> uncheck
        - In Stage Manager -> uncheck

### Finder

- Finder -> Preferences
  - General -> Show these on the desktop -> Select None
    - I try to keep my desktop completely clean.
  - General -> New Finder windows show -> Home Folder
    - I prefer to see my home folder in each new finder window instead of recent documents
  - Advanced -> Show all filename extensions -> Yes
  - Advanced -> Show warning before changing an extension -> No
  - Advanced -> When performing a search -> Search the current folder
- View
  - Show Status Bar
  - Show Path Bar
  - Show Tab Bar

### Dock

I don't use the Dock at all. It takes up screen space, and I can use RayCast to launch apps and AltTab to switch between apps. I make the dock as small as possible and auto hide it.

- System Preferences
  - Desktop & Dock
    - Size -> Small as possible
    - Position on screen -> Left
    - Automatically hide and show the Dock -> Yes
    - Animate opening applications -> No
    - Show suggested and recent apps in the Dock -> No

## Quick Launching

The built in spotlight search is a bit slow for me and usually has web search results as the default instead of apps or folders on my machine.

I use [Alfred](https://www.alfredapp.com/) because its much faster and it gives me what i need exactly.

```sh
brew install alfred
```

## Homebrew

### Homebrew

[Homebrew](https://brew.sh/) allows us to install tools and apps from the command line.

To install it, open up the built in `Terminal` app and run this command:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

This will also install the xcode build tools which is needed by many other developer tools.

After Homebrew is done installing, we will use it later to install everything else we need.

## Window Management

I know this feature is built in to a lot of other operating systems, but it is not built in to a Mac, so we need an app for it.

I use [rectangle](https://rectangleapp.com/) to move and resize windows using keyboard shortcuts.

I highly recommend installing this and memorizing the keyboard shortcuts. Fluid and seamless window management is key to being productive while coding.

Search for `rectangle` in alfred `brew search` or:

```
brew install rectangle
```

## App Switching

The built in App switcher only shows application icons, and only shows 1 icon per app regardless of how many windows you have open in that app.

I use an app switcher called [AltTab](https://alt-tab-macos.netlify.app/). It shows full window previews, and has an option to show a preview for every open window in all applications (even minimized ones).

I replace the built-in `CMD+TAB` shortcut with AltTab.

Search for `alt-tab` in RayCast `brew search` or:

```sh
brew install alt-tab
```

## Other Apps I Use Daily

- [discord](https://discord.com/) - Messaging / Community
- [vlc](https://www.videolan.org/) - I use VLC to watch videos instead of the built in QuickTime.
- [keka](https://www.keka.io/en/) - Can extract 7z / rar and other types of archives
- [visual-studio-code](https://code.visualstudio.com/) - Code Editor
- [sublime-text](https://www.sublimetext.com/) - Note taking (I know there are better apps...)

You can install them in one go by placing them all into a text file and then running brew install:

```
discord
slack
vlc
keka
visual-studio-code
sublime-text
postman
```

```sh
xargs brew install < apps.txt
```

### Docker

There are multiple results when you search `docker` within `brew`. To install Docker desktop:

```sh
brew install --cask docker
```

## Terminal

I prefer [iTerm2](https://iterm2.com/) because:

- Lots of customization options
- Clickable links
- Native OS notifications

There are a lot of options for a terminal replacement, but I've been using iTerm2 and it works great for my needs.

Checkout their documentation for more info on what iTerm2 can do: [https://iterm2.com/documentation.html](https://iterm2.com/documentation.html)

```
brew install iterm2
```

Once installed, launch it and customize the settings / preferences to your liking. These are my preferred settings:

- Appearance
  - Theme
    - Minimal
- Profiles
  - Default
    - General -> Working Directory -> Reuse previous session's directory
    - Colors -> Basic Colors -> Foreground -> Lime Green
    - Text -> Font -> Anonymous Pro
      - You can download this font [here](https://www.marksimonson.com/fonts/view/anonymous-pro).
      - I use this font in VS Code as well
    - Text -> Font Size -> 36
      - I use my Macbook to present / teach, so a big font size is important so everyone can see the commands I'm typing
    - Keys -> Key Mappings -> Presets -> Natural Text Editing
      - This allows me to use the [keyboard shortcuts](https://gist.github.com/w3cj/022081eda22081b82c52) I know and love inside of iTerm2

### Shell

Mac now comes with `zsh` as the default [shell](https://en.wikipedia.org/wiki/Comparison_of_command_shells). I've switched to using this with [Oh My Zsh](https://ohmyz.sh/).

#### Load dotfiles

All my macsetup files are stored on [github](https://github.com/gameshler/macsetup).

I clone this repo to my machine and copy the files into my home directory.

### Github SSH Setup

- Follow [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) to setup an ssh key for github
- Follow [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) to add the ssh key to your github account

#### Other command line tools I use

- [ffmpeg](https://en.wikipedia.org/wiki/FFmpeg) - edit videos from the command line
- [imagemagick](https://en.wikipedia.org/wiki/ImageMagick) - edit images from the command line

```sh
brew install ffmpeg
brew install imagemagick
```

## Node.js

I use nvm to manage the installed versions of Node.js on my machine. This allows me to easily switch between Node.js versions depending on the project I'm working in.

See installation instructions [here](https://github.com/nvm-sh/nvm#installing-and-updating).

OR run this command (make sure v0.39.7 is still the latest)

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

Now that nvm is installed, you can install a specific version of node.js and use it:

```sh
nvm install 20
nvm use 20
node --version
```

### Global Modules

There are a few global node modules I use a lot:

- lite-server
  - Auto refreshing static file server. Great for working on static apps with no build tools.
- http-server
  - Simple static file server.
- license
  - Auto generate open source license files
- gitignore
  - Auto generate `.gitignore` files base on the current project type

```
npm install -g lite-server http-server license gitignore
```
