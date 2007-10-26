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

typedef unsigned char  uchar;
typedef unsigned short ushort;

char trace[10000];
char tmp_trace1[80];
char tmp_trace2[80];

void
address_encoder(ushort address_in, uchar *address_out)
{
    int i;

    for (i=0; i < 4; i++) {
	// For a given short 0x1234, work our way from the
	// highest-order nybble (1) to the lowest (4).
	uchar nybble = (address_in >> (4 * (3 - i))) & 0x0F;

	// The encoded address is that nybble embedded into 0x82, e.g.:
	//  0x82 =  1000 0010
	//  0xF  =    11 11
	address_out[i] = (uchar) (0x82 | (nybble << 2));
    }

    return;
}


/********************************************************************
 * data_encoder converts up to 15 data bytes to the form needed
 * by the WS-2300 when sending write commands.
 *
 * Input:   number - number of databytes (integer)
 *          encode_constant - unsigned char
 *                            0x12=set bit, 0x32=unset bit, 0x42=write nibble
 *          data_in - char array with up to 15 hex values
 *
 * Output:  address_out - Pointer to an unsigned character array.
 *
 * Returns: Nothing.
 *
 ********************************************************************/
void data_encoder(int number, uchar encode_constant,
                  uchar *data_in, uchar *data_out)
{
	int i = 0;

	for (i = 0; i < number; i++)
	{
		data_out[i] = (uchar) (encode_constant + (data_in[i] * 4));
	}

	return;
}


/********************************************************************
 * numberof_encoder converts the number of bytes we want to read
 * to the form needed by the WS-2300 when sending commands.
 *
 * Input:   number interger, max value 15
 *
 * Returns: unsigned char which is the coded number of bytes
 *
 ********************************************************************/
unsigned char
numberof_encoder(uchar number)
{
    return (uchar) (0xC2 | (number<<2));
}


/********************************************************************
 * command_check0123 calculates the checksum for the first 4
 * commands sent to WS2300.
 *
 * Input:   pointer to char to check
 *          sequence of command - i.e. 0, 1, 2 or 3.
 *
 * Returns: calculated checksum as unsigned char
 *
 ********************************************************************/
uchar
command_check0123(uchar *command, int sequence)
{
	int response;

	response = sequence * 16 + ((*command) - 0x82) / 4;

	return (uchar) response;
}


/********************************************************************
 * command_check4 calculates the checksum for the last command
 * which is sent just before data is received from WS2300
 *
 * Input: number of bytes requested
 *
 * Returns: expected response from requesting number of bytes
 *
 ********************************************************************/
uchar
command_check4(int number)
{
	int response;

	response = 0x30 + number;

	return response;
}


/********************************************************************
 * data_checksum calculates the checksum for the data bytes received
 * from the WS2300
 *
 * Input:   pointer to array of data to check
 *          number of bytes in array
 *
 * Returns: calculated checksum as unsigned char
 *
 ********************************************************************/
uchar
data_checksum(uchar *data, uchar count)
{
    int i;
    unsigned int checksum = 0;

    for (i = 0; i < count; i++) {
	checksum += data[i];
    }

    return checksum & 0xFF;
}


















int read_device(int fh, uchar *buffer, int size)
{
    int bytes_read = 0;
    int i;

    strcat(trace,"<<");

    while (bytes_read < size) {
	int ret = read(fh, buffer+bytes_read, size-bytes_read);
	if (ret < 0)
	  continue;

	if (ret == 0) {
	    // Nothing read.  Wait up to 1 second for more data.
	    fd_set readfd;
	    struct timeval timeout = { 1, 0 };

	    FD_ZERO(&readfd);
	    FD_SET(fh, &readfd);

	    if (! select(fh+1, &readfd, 0, 0, &timeout)) {
		// Timed out with nothing to read.  Abort.
		fprintf(stderr,"Yuk. Read %d of %d bytes.\n",bytes_read,size);
		strcat(trace, "**FAILED**\n");
		fprintf(stderr,trace);
		return bytes_read;
	    }

	    // select() says there's more to read
	}

	bytes_read += ret;
    }

    // Yay!
    tmp_trace1[0] = '\0';
    for (i=0; i < size; i++) {
      sprintf(tmp_trace2, " %02X", buffer[i]);
      strcat(tmp_trace1, tmp_trace2);
    }
    strcat(trace, tmp_trace1);
    strcat(trace,"\n");

    return bytes_read;
}



int
write_device(int fh, uchar *buffer, int size)
{
  int i;
	int ret = write(fh, buffer, size);

	sprintf(tmp_trace1,">>");
	for (i=0; i < size; i++) {
	  sprintf(tmp_trace2, " %02X", buffer[i]);
	  strcat(tmp_trace1, tmp_trace2);
	}
	strcat(trace, tmp_trace1);

	if (ret != size) {
	  fprintf(stderr,"write failed: size=%d ret=%d errno=%d\n",
		  size,ret,errno);
	  strcat(trace, " *FAILED*");
	}
	else {
	  strcat(trace, "\n");
	}
	tcdrain(fh);	// wait for all output written
	return ret;
}


int
write_readback(int fh, uchar byte, uchar expect)
{
    uchar buf[16];

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
    uchar reset = 0x06;
    uchar answer;
    int i;
    fd_set readfd;
    struct timeval timeout = { 0, 0 };

    trace[0] = '\0';
    for (i = 0; i < 10; i++) {
	// Discard any garbage in the input buffer
	tcflush(fh, TCIOFLUSH);

	FD_ZERO(&readfd);
	FD_SET(fh, &readfd);
	if (select(fh+1, &readfd, 0, 0, &timeout))
	  printf("got here: select says there's something to read\n");

	write_device(fh, &reset, 1);
	// Occasionally 0, then 2 is returned.  If zero comes back, continue
	// reading as this is more efficient than sending an out-of sync
	// reset and letting the data reads restore synchronization.
	// Occasionally, multiple 2's are returned.  Read with a fast timeout
	// until all data is exhausted, if we got a two back at all, we
	// consider it a success
	while (1 == read_device(fh, &answer, 1)) {
	    if (answer == 2) {
		return;
	    }
	    else {
	      printf("unexpected reply after reset: %X\n", answer);
	    }
	}

	//	usleep(50000 * i);   //we sleep longer and longer for each retry
    }
    fprintf(stderr, "\nCould not reset\n");
    exit(EXIT_FAILURE);
}


int
read_data(int fh, ushort address, uchar count, uchar *readdata)
{

	uchar answer;
	uchar commanddata[40];
	int i;

	// First 4 bytes are populated with converted address range 0000-13B0
	address_encoder(address, commanddata);
	// Last populate the 5th byte with the converted number of bytes
	commanddata[4] = numberof_encoder(count);

	for (i = 0; i < 4; i++)
	{
	  uchar expect = command_check0123(commanddata + i, i);

	  if (write_readback(fh, commanddata[i], expect) != 1)
	    return -1;
	}

	//Send the final command that asks for 'number' of bytes, check answer
	if (write_readback(fh,commanddata[4],command_check4(count)) != 1)
		return -1;

	//Read the data bytes
//	for (i = 0; i < count; i++)
//	{
//		if (read_device(fh, readdata + i, 1) != 1)
		if (read_device(fh, readdata, count) != count)
		  { fprintf(stderr,"read_data:read_device(3)\n");
			return -1;
		  }
//	}

	//Read and verify checksum
	if (read_device(fh, &answer, 1) != 1)
		  { fprintf(stderr,"read_data:read_device(4)\n");
		return -1;
		  }
	if (answer != data_checksum(readdata, count))
		  { fprintf(stderr,"read_data:data_checksum(1)\n");
		return -1;
		  }

	return count;

}



int
read_safe(int fh, ushort address, ushort count, uchar *buf)
{
    int i;

    for (i=0; i < 10; i++) {
	// If we get the expected number of bytes, we're done.
	if (read_data(fh, address, count, buf) == count)
	    return 1;

	// FIXME: warn?  Reset?
//	reset_06(fh);
    }

    return 0;
}




MODULE = Device::LaCrosse::WS23xx	PACKAGE = Device::LaCrosse::WS23xx


int
open_2300(path)
	char *     path
    INIT:
	int serial_device;
	struct termios adtio;
	int portstatus, fdflags;
    PPCODE:
	//Setup serial port
	if ((serial_device = open(path, O_RDWR | O_NONBLOCK | O_SYNC)) < 0)
	{
	    fprintf(stderr,"\nUnable to open serial device %s\n", path);
	    XSRETURN_UNDEF;
	}

	if ( flock(serial_device, LOCK_EX|LOCK_NB) < 0 ) {
	    fprintf(stderr,"\nSerial device is locked by other program\n");
	    XSRETURN_UNDEF;
	}

	if ((fdflags = fcntl(serial_device, F_GETFL)) == -1 ||
	     fcntl(serial_device, F_SETFL, fdflags & ~O_NONBLOCK) < 0)
	{
		perror("couldn't reset non-blocking mode");
		exit(EXIT_FAILURE);
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
	    XSRETURN_UNDEF;
	}

	tcflush(serial_device, TCIOFLUSH);

	// Set DTR low and RTS high and leave other ctrl lines untouched
	ioctl(serial_device, TIOCMGET, &portstatus);	// get current port status
	portstatus &= ~TIOCM_DTR;
	portstatus |= TIOCM_RTS;
	ioctl(serial_device, TIOCMSET, &portstatus);	// set current port status

	// Reset the device, just once
	reset_06(serial_device);

	XPUSHs(sv_2mortal(newSVnv(serial_device)));


void
read_2300(fh, addr, count)
	int fh
	unsigned short addr
	unsigned char count
    PREINIT:
	uchar buf[40];
    PPCODE:
#if	DEBUG
	printf("got here: fh=%d addr=%04X count=%d\n", fh, addr, count);
#endif
	if (read_safe(fh, addr, count, buf)) {
	    int i;

	    for (i=0; i < count; i += 2) {
		XPUSHs(sv_2mortal(newSVnv(buf[i/2] & 0x0F)));
		if (i < count-1)
		    XPUSHs(sv_2mortal(newSVnv(buf[i/2] >> 4)));
	    }
	}
	else {
	    croak("read_safe failed");
	}
