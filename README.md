`repos.conf/negril.conf`

```ini
[negril]
location = /var/db/repos/negril
sync-type = git
sync-uri = https://github.com/negril/gentoo-overlay.git
auto-sync = no
sync-git-clone-extra-opts = --branch=master
; sync-git-pull-extra-opts = --branch=master

[negril-gpgpu]
location = /var/db/repos/negril-gpgpu
sync-type = git
sync-uri = https://github.com/negril/gentoo-overlay.git
auto-sync = no
; stable
sync-git-clone-extra-opts = --branch=gpgpu/master
; sync-git-pull-extra-opts = --branch=gpgpu/master
; ; unstable
; sync-git-clone-extra-opts = --branch=gpgpu/test
; ; sync-git-pull-extra-opts = --branch=gpgpu/test

[negril-slam]
location = /var/db/repos/negril-slam
sync-type = git
sync-uri = https://github.com/negril/gentoo-overlay.git
auto-sync = no
sync-git-clone-extra-opts = --branch=slam/master
; sync-git-pull-extra-opts = --branch=slam/master

[negril-vfx]
location = /var/db/repos/negril-vfx
sync-type = git
sync-uri = https://github.com/negril/gentoo-overlay.git
auto-sync = no
; stable
sync-git-clone-extra-opts = --branch=vfx/master
; sync-git-pull-extra-opts = --branch=vfx/master
; ; unstable
; sync-git-clone-extra-opts = --branch=vfx/dev
; ; sync-git-pull-extra-opts = --branch=vfx/dev
```
