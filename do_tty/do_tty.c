/*
 * do_tty.c - v 1.2 by Stefan `Sec` Zehl <sec@42.org> - 17.02.98 02:21
 * do_tty.c - v 1.3 by Stefan `Sec` Zehl <sec@42.org> - 20.08.98 00:46
 * do_tty.c - v 1.4 by Stefan `Sec` Zehl <sec@42.org> - 05.12.03 00:16
 *
 * Types something on another tty via TIOCSTY
 *
 * Do whatever you like with this program, as long as you leave the copyright
 * notice intact.
 *
 * This code is under the 2-Clause BSD licence
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
	char   c;
	int    fd;

	if(argc != 3){
		printf("usage: %s <device> <string>\n",argv[0]);
		printf("       <device> needs the full pathname\n");
		printf("       <string> may contain ^character\n");
		printf("                and the usual c-type \\-escapes\n");
		exit(1);
	}

	device= argv[1];
	string= argv[2];

	if ((fd = open(device, 2)) < 0){
		perror("open");
		exit(1);
	}

	while((c=*(string++))){
		if (c == '^'){			/* Control-characters */
			c=*(string++);
			if(c > 64){
				if((c >96)&&(c<123))
					c-=32;
				c-=64;
			} else if (c==0){
				fprintf(stderr,"String ends in escape\n");
				exit(1);
			};
		} else if (c == '\\'){	/* Backslash-Escaped */
			switch (c=*(string++)){
				case 'a': c='\a';break;
				case 'b': c='\b';break;
				case 'f': c='\f';break;
				case 'n': c='\n';break;
				case 'r': c='\r';break;
				case 't': c='\t';break;
				case 'v': c='\v';break;
				case '0': c=0   ;break;
				case  0 : 
						  fprintf(stderr,"String ends in escape\n");
						  exit(1);
						  break;
			}
		}
		if (ioctl(fd, TIOCSTI, &c) < 0){
			perror("TIOCSTI");
			exit(1);
		}
	}
	return(0);
}
