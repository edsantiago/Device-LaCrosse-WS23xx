/* -*- c -*-
**
** Filename: NIS.xs - back end for the Net::NIS package
**
** $Id: NIS.xs,v 1.8 2004/12/20 13:32:55 esm Exp $
*/

#include <sys/types.h>		/* Needed on FreeBSD */
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/*
** The *THX_ macros seem to be 5.6 and above.
**
** Nobody should be running 5.005 any more, but still, it's not my place
** to judge.  If someone wants to, let's try to let them.
*/
#ifndef	 pTHX_
# define pTHX_
#endif	/* pTHX */




int read_device(int fh, unsigned char *buffer, int size)
{
	int ret;
	fd_set readfd;
	struct timeval timeout = { 3, 0 };

	FD_ZERO(&readfd);
	FD_SET(fh, &readfd);

	for (;;) {
	  int foo;
	  foo=select(fh+1, &readfd, 0, 0, &timeout);

		ret = read(fh, buffer, size);
#if DEBUG
		if (ret <= 0)
		  fprintf(stderr,"read failed: foo=%d errno=%d\n",foo,errno);
#endif
		if (ret == 0 && errno == EINTR)
			continue;
		return ret;
	}
}



int write_device(int fh, unsigned char *buffer, int size)
{
	int ret = write(fh, buffer, size);
	if (ret != size)
	  fprintf(stderr,"write failed: size=%d ret=%d errno=%d\n",
		  size,ret,errno);
	tcdrain(fh);	// wait for all output written
	return ret;
}


int write_readback(int fh, unsigned char byte, unsigned char expect)
{
	unsigned char buf[16];

	if (write_device(fh, &byte, 1) != 1) {
#if DEBUG
		fprintf(stderr,"Error writing byte[%X]\n", byte);
#endif
		return -1;
	}

	if (read_device(fh, buf, 1) != 1) {
#if DEBUG
		fprintf(stderr,"Error reading byte after sending %02X\n",byte);
#endif
		return -1;
	}

	if (buf[0] != expect) {
#if DEBUG
		fprintf(stderr,"write_readback: sent %02X, expected %02X, got %02X\n", byte, expect, buf[0]);
#endif
		return -1;
	}

	return 1;
}









void reset_06(int fh)
{
    unsigned char command = 0x06;
    unsigned char answer;
    int i;
    fd_set readfd;
    struct timeval timeout = { 0, 0 };

    /* Anything pending from device?  Flush it. */
    FD_ZERO(&readfd);
    FD_SET(fh, &readfd);

    for (i = 0; i < 100; i++) {
	// Discard any garbage in the input buffer
	tcflush(fh, TCIOFLUSH);

	write_device(fh, &command, 1);
	// Occasionally 0, then 2 is returned.  If zero comes back, continue
	// reading as this is more efficient than sending an out-of sync
	// reset and letting the data reads restore synchronization.
	// Occasionally, multiple 2's are returned.  Read with a fast timeout
	// until all data is exhausted, if we got a two back at all, we
	// consider it a success
	while (1 == read_device(fh, &answer, 1)) {
	    if (answer == 2) {
		if (select(fh+1, &readfd, 0, 0, &timeout)) {
		    fprintf(stderr,"Got here: more to read!\n");
		}
		return;
	    }
	}

	//	usleep(50000 * i);   //we sleep longer and longer for each retry
	}
	fprintf(stderr, "\nCould not reset\n");
	exit(EXIT_FAILURE);
}


int read_data(int fh, int address, int number, unsigned char *readdata)
{

	unsigned char answer;
	unsigned char commanddata[40];
	int i;

	// First 4 bytes are populated with converted address range 0000-13B0
	address_encoder(address, commanddata);
	// Last populate the 5th byte with the converted number of bytes
	commanddata[4] = numberof_encoder(number);

	for (i = 0; i < 4; i++)
	{
	  unsigned char expect = command_check0123(commanddata + i, i);

	  if (write_readback(fh, commanddata[i], expect) != 1)
	    return -1;
	}

	//Send the final command that asks for 'number' of bytes, check answer
	if (write_readback(fh,commanddata[4],command_check4(number)) != 1)
		return -1;

	//Read the data bytes
	for (i = 0; i < number; i++)
	{
		if (read_device(fh, readdata + i, 1) != 1)
		  { fprintf(stderr,"read_data:read_device(3)\n");
			return -1;
		  }
	}

	//Read and verify checksum
	if (read_device(fh, &answer, 1) != 1)
		  { fprintf(stderr,"read_data:read_device(4)\n");
		return -1;
		  }
	if (answer != data_checksum(readdata, number))
		  { fprintf(stderr,"read_data:data_checksum(1)\n");
		return -1;
		  }

	return i;

}



int read_safe(int fh, int address, int count, unsigned char *buf)
{
	reset_06(fh);

	// Read the data. If expected number of bytes read break out of loop.
	if (read_data(fh, address, count, buf)==count)
	{
	  return 1;
	}

	return 0;
}




MODULE = Open2300	PACKAGE = Open2300


int
open_2300(path)
	char *     path
    INIT:
	int serial_device;
	struct termios adtio;
	int portstatus;
    CODE:
	RETVAL = 0;

	//Setup serial port
	if ((serial_device = open(path, O_RDWR | O_NOCTTY)) < 0)
	{
	    fprintf(stderr,"\nUnable to open serial device %s\n", path);
	    return;
	}

	if ( flock(serial_device, LOCK_EX) < 0 ) {
	    fprintf(stderr,"\nSerial device is locked by other program\n");
	    return;
	}


	tcgetattr(serial_device, &adtio);

	// Serial control options
	adtio.c_cflag &= ~PARENB;      // No parity
	adtio.c_cflag &= ~CSTOPB;      // One stop bit
	adtio.c_cflag &= ~CSIZE;       // Character size mask
	adtio.c_cflag |= CS8;          // Character size 8 bits
	adtio.c_cflag |= CREAD;        // Enable Receiver
	adtio.c_cflag &= ~HUPCL;       // No "hangup"
	adtio.c_cflag &= ~CRTSCTS;     // No flowcontrol
	adtio.c_cflag |= CLOCAL;       // Ignore modem control lines

	// Baudrate, for newer systems
	cfsetispeed(&adtio, B2400);
	cfsetospeed(&adtio, B2400);

	// Serial local options: adtio.c_lflag
	// Raw input = clear ICANON, ECHO, ECHOE, and ISIG
	// Disable misc other local features = clear FLUSHO, NOFLSH, TOSTOP, PENDIN, and IEXTEN
	// So we actually clear all flags in adtio.c_lflag
	adtio.c_lflag = 0;

	// Serial input options: adtio.c_iflag
	// Disable parity check = clear INPCK, PARMRK, and ISTRIP
	// Disable software flow control = clear IXON, IXOFF, and IXANY
	// Disable any translation of CR and LF = clear INLCR, IGNCR, and ICRNL
	// Ignore break condition on input = set IGNBRK
	// Ignore parity errors just in case = set IGNPAR;
	// So we can clear all flags except IGNBRK and IGNPAR
	adtio.c_iflag = IGNBRK|IGNPAR;

	// Serial output options
	// Raw output should disable all other output options
	adtio.c_oflag &= ~OPOST;

	adtio.c_cc[VTIME] = 10;		// timer 1s
	adtio.c_cc[VMIN] = 0;		// blocking read until 1 char

	if (tcsetattr(serial_device, TCSANOW, &adtio) < 0)
	{
	    fprintf(stderr,"Unable to initialize serial device");
	    exit(EXIT_FAILURE);
	}

	tcflush(serial_device, TCIOFLUSH);

	// Set DTR low and RTS high and leave other ctrl lines untouched
	ioctl(serial_device, TIOCMGET, &portstatus);	// get current port status
	portstatus &= ~TIOCM_DTR;
	portstatus |= TIOCM_RTS;
	ioctl(serial_device, TIOCMSET, &portstatus);	// set current port status

	RETVAL = serial_device;
    OUTPUT:
	RETVAL


void
read_2300(fh, addr, count)
	int fh
	short addr
	short count
    PREINIT:
	unsigned char buf[40];
    PPCODE:
	printf("got here: %04X - %d\n", addr, count);
	if (read_safe(fh, addr, count, buf)) {
	    int i;

	    for (i=0; i < count; i += 2) {
		XPUSHs(sv_2mortal(newSVnv(buf[i] & 0x0F)));
		if (i < count-1)
		    XPUSHs(sv_2mortal(newSVnv(buf[i] >> 4)));
	    }
	}
	else {
	    croak("foo");
	}
