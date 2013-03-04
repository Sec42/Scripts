/*
 * do_tty.c - v 1.2 by Stefan `Sec` Zehl <sec@42.org> - 17.02.98 02:21
 * do_tty.c - v 1.3 by Stefan `Sec` Zehl <sec@42.org> - 20.08.98 00:46
 *
 * Types something on another tty via TIOCSTY
 *
 * Do whatever you like with this program, as long as you leave the copyright
 * notice intact.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <fcntl.h>

int main(int argc,char **argv)
{
	char * device;
	char * string;
	int     fd;

	if(argc != 3){
		printf("usage: %s <device> <string>\n",argv[0]);
		printf("       <device> needs the full pathname\n");
		printf("       <string> may contain ^character\n");
		printf("                and the usual c-type \\-escapes\n");
		exit(1);
	}

	device = argv[1];
	string=(char *)calloc(1,strlen(argv[2])+3);
	strcpy(string,argv[2]);
	string[100]=0;

	/*
	 * Open the device.
	 */

	if ((fd = open(device, 2)) < 0){
		perror("open");
		exit(1);
	}

	while(*(string)){
		if (*string == '^'){
			string++;
			if(*string > 64){
				if((*string >96)&&(*string<123))
					*string-=32;
				*string-=64;
			}
		} else if (*string == '\\'){
			switch (*(++string)){
				case 'a': *string='\a';break;
				case 'b': *string='\b';break;
				case 'f': *string='\f';break;
				case 'n': *string='\n';break;
				case 'r': *string='\r';break;
				case 't': *string='\t';break;
				case 'v': *string='\v';break;
			}
		}
		if (ioctl(fd, TIOCSTI, string++) < 0){
			perror("TIOCSTI");
			exit(1);
		}
	}
	return(0);
}
