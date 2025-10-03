
include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = IVXVTester

IVXVTester_OBJC_FILES = main.m ../VVK/Group.m ../VVK/Scalar.m ../VVK/ElgamalPub.m \
		../VVK/GroupECC.m ../VVK/GroupModP.m ../VVK/Ballot.m ../VVK/PkixHelper.m \
		../VVK/OcspHelper.m

IVXVTester_C_FILES = ../VVK/ElGamalCiphertext.c
IVXVTester_CPPFLAGS += -I../VVK -I/usr/include
IVXVTester_OBJCFLAGS += -std=gnu11

ADDITIONAL_TOOL_LIBS += -L/usr/lib/x86_64-linux-gnu -lssl -lcrypto

include $(GNUSTEP_MAKEFILES)/application.make
