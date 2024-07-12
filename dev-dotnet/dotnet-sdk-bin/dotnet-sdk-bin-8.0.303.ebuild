# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SDK="8.0.303"

DESCRIPTION="Full .NET Core SDK (binary)"
HOMEPAGE="https://dotnet.microsoft.com/"

SRC_URI="
amd64? (
elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-x64.tar.gz )
)
"

S=${WORKDIR}

LICENSE="MIT"
SLOT="8.0"
KEYWORDS="~amd64 ~arm ~arm64"
QA_PREBUILT="*"
RESTRICT+=" splitdebug"

REQUIRED_USE="|| ( elibc_glibc elibc_musl )"

RDEPEND="
	>=dev-dotnet/aspnetcore-runtime-bin-8.0.7:8.0
	>=dev-dotnet/aspnetcore-targeting-pack-bin-8.0.7:8.0
	>=dev-dotnet/dotnet-runtime-bin-8.0.7:8.0
	>=dev-dotnet/dotnet-targeting-pack-bin-8.0.7:8.0
	>=dev-dotnet/dotnet-apphost-pack-bin-8.0.7:8.0
	>=dev-dotnet/dotnet-templates-bin-8.0.7:8.0
"

src_install() {
	local dotnet_root="opt/dotnet"
	dodir "${dotnet_root%/*}"

	# Create a magic workloads file, bug #841896
	local featureband="$(ver_cut 3 | sed "s/[0-9][0-9]$/00/g")"
	local workloads="metadata/workloads/${SLOT}.${featureband}"
	mkdir -p "${workloads}"
	touch "${workloads}/userlocal"

	insinto "${dotnet_root}"
	doins -r sdk sdk-manifests
	[[ -d "library-packs" ]] && doins -r "library-packs"
	[[ -d "template-packs" ]] && doins -r "template-packs"
	[[ -d "metadata/workloads" ]] && { insinto "${dotnet_root}/metadata"; doins -r metadata/workloads; }
}
