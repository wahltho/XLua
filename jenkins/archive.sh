#!/usr/bin/env bash
BUILD_PRODUCTS_DIR="${BUILD_PRODUCTS_DIR:-jenkins/build_products}"

case "$PLATFORM" in
"IBM")
	echo "${BUILD_PRODUCTS_DIR}/xlua_win.xpl"
	;;
"APL")
	echo "${BUILD_PRODUCTS_DIR}/xlua_mac.xpl"
	;;
"LIN")
	echo "${BUILD_PRODUCTS_DIR}/xlua_lin.xpl"
	;;
esac
