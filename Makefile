include $(FAB_PATH)/common/mk/turnkey/web2py.mk

# The shared Web2py configuration follows an unpinned latest-release lookup.
# Keep its Trixie packages and overlays, but install the pinned supported source
# from this appliance instead.
COMMON_CONF := $(filter-out web2py,$(COMMON_CONF))

include $(FAB_PATH)/common/mk/turnkey.mk
