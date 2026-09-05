#!/usr/bin/env bash

if [ -z "${PLATFORM}" ]; then
	echo "PLATFORM not set properly - it must be one of APL IBM or LIN"
	exit 1
fi

WANT_CODESIGN="${WANT_CODESIGN:-NO}"
XLUA_BUILD_ROOT="${XLUA_BUILD_ROOT:-${HOME}/dev/xlua}"
XLUA_BUILD_ROOT="${XLUA_BUILD_ROOT%/}"
XLUA_WORK_ROOT="${XLUA_BUILD_ROOT}/work"
MAC_BUILD_ROOT="${XLUA_WORK_ROOT}/mac"
LIN_BUILDDIR="${LIN_BUILDDIR:-${XLUA_WORK_ROOT}/linux/build}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${MAC_BUILD_ROOT}/DerivedData}"
MAC_ARCHIVE_PATH="${MAC_ARCHIVE_PATH:-${MAC_BUILD_ROOT}/XLua.xcarchive}"
MAC_ZIP_PATH="${MAC_ZIP_PATH:-${MAC_BUILD_ROOT}/xlua_mac.zip}"
BUILD_PRODUCTS_DIR="${BUILD_PRODUCTS_DIR:-jenkins/build_products}"

function clean() {
	rm -rf xlua.xcarchive
	rm -rf XLua.xcarchive
	rm -rf xlua_mac.zip
	rm -rf DerivedData
	rm -rf build
	rm -rf Debug
	rm -rf Release
	rm -rf "${MAC_ARCHIVE_PATH}"
	rm -rf "${MAC_ZIP_PATH}"
	mkdir -p "${MAC_BUILD_ROOT}"
	mkdir -p "${BUILD_PRODUCTS_DIR}"
}

echo Removing old build products... 
rm -rf "${BUILD_PRODUCTS_DIR}/"
clean

case "$PLATFORM" in
"IBM")
	MSBUILD="$MSVC_ROOT"/MSBuild/Current/Bin/MSBuild.exe 
	MSBUILD_PROPS=(
		/p:Configuration="Release"
		/p:Platform="x64"
	)
	if [ -n "${WIN_OUT_DIR:-}" ]; then
		MSBUILD_PROPS+=(/p:OutDir="${WIN_OUT_DIR}")
	fi
	if [ -n "${WIN_INT_DIR:-}" ]; then
		MSBUILD_PROPS+=(/p:IntDir="${WIN_INT_DIR}")
	fi
	"$MSBUILD" xlua.vcxproj /t:Clean "${MSBUILD_PROPS[@]}"
	"$MSBUILD" /m "${MSBUILD_PROPS[@]}" xlua.vcxproj
	WIN_OUTPUT_DIR="${WIN_OUT_DIR:-Release/plugins/win_x64}"
	echo mv "${WIN_OUTPUT_DIR}/xlua.pdb" "${BUILD_PRODUCTS_DIR}/xlua_win.pdb"
	mv "${WIN_OUTPUT_DIR}/xlua.pdb" "${BUILD_PRODUCTS_DIR}/xlua_win.pdb"
	echo mv "${WIN_OUTPUT_DIR}/xlua.xpl" "${BUILD_PRODUCTS_DIR}/xlua_win.xpl"
	mv "${WIN_OUTPUT_DIR}/xlua.xpl" "${BUILD_PRODUCTS_DIR}/xlua_win.xpl"
	;;
"APL")
	
	CODE_SIGN_ARGS=()
	if [ "${WANT_CODESIGN}" == "YES" ]; then
		CODE_SIGN_ARGS=(
			CODE_SIGN_STYLE="Manual"
			CODE_SIGN_IDENTITY="Developer ID Application: Laminar Research (LPH4NFE92D)"
		)
	else
		CODE_SIGN_ARGS=(
			CODE_SIGNING_ALLOWED=NO
			CODE_SIGN_STYLE="Manual"
			CODE_SIGN_IDENTITY=""
		)
	fi

	echo Cleaning...
	xcodebuild \
		-scheme xlua \
		-config Release \
		-project xlua.xcodeproj \
		-derivedDataPath "${DERIVED_DATA_PATH}" \
		"${CODE_SIGN_ARGS[@]}" \
		clean

	echo Compiling...
	xcodebuild \
		-scheme xlua \
		-config Release \
		-project xlua.xcodeproj \
		-archivePath "${MAC_ARCHIVE_PATH}" \
		-derivedDataPath "${DERIVED_DATA_PATH}" \
		"${CODE_SIGN_ARGS[@]}" \
		archive

	if [ "${WANT_CODESIGN}" == "YES" ]; then
		echo Notarizing...
		./build-tools/mac/notarization.sh \
				"${MAC_ZIP_PATH}" \
				"${MAC_ARCHIVE_PATH}/Products/usr/local/lib/xlua.xpl" \
				no-staple
	fi
	
	mv "${MAC_ARCHIVE_PATH}/Products/usr/local/lib/xlua.xpl" "${BUILD_PRODUCTS_DIR}/xlua_mac.xpl"
	;;
"LIN")
	make BUILDDIR="${LIN_BUILDDIR}" clean
	make BUILDDIR="${LIN_BUILDDIR}"
	cp "${LIN_BUILDDIR}/xlua/64/lin.xpl" "${BUILD_PRODUCTS_DIR}/xlua_lin.xpl"
	;;
*)
	echo "PLATFORM not set properly - it must be one of APL IBM or LIN"
	exit 1
	;;
esac
