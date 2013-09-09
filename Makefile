INSTALL_DIR=/gpfs1m/apps/utils/bin/tfr
CP=/bin/cp -f
MKDIR=/bin/mkdir -p

all:
	make -C queue_check

clean:
	make -C queue_check clean

install:
	${MKDIR} ${INSTALL_DIR}
	${MKDIR} -p ${INSTALL_DIR}/lib
	${INSTALL} -m 755 tfr_handler ${INSTALL_DIR}/tfr_handler
	${INSTALL} -m 644 lib/argparser.rb ${INSTALL_DIR}/lib/argparser.rb
	${INSTALL} -m 755 tfr_queue ${INSTALL_DIR}/tfr_queue
