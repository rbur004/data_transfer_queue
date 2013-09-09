INSTALL_DIR=/gpfs1m/apps/utils/bin/tfr
INSTALL=/usr/bin/install -b
MKDIR=/bin/mkdir
RM=/bin/rm
CC=gcc

all: tfr_q_check

tfr_q_check: tfr_q_check.h tfr_q_check.c
	${CC} -o tfr_q_check tfr_q_check.c -llockfile

install: all
	${MKDIR} -p ${INSTALL_DIR}
	${INSTALL} -m 755 tfr_q_check ${INSTALL_DIR}/tfr_q_check

clean:
	${RM} -f *.o *.a tfr_q_check
