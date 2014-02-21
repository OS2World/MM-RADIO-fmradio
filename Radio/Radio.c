
#define INCL_DOSDEVICES   /* Device values */
#define INCL_PM
#include <os2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define IS_STEREO 	0x22   /*IOCtlcmds */
#define IS_TUNE	  	0x24
#define SET_FREQ  	0x62
#define SET_STEREO	0x64
#define SET_MUTE	0x66

void main(int argc,char *argv[])
{
 ULONG 	 Freq[1];
 SHORT   Data[1];
 HFILE   DevHandle;
 ULONG   Action=2;
 ULONG   Parmlen=2;
 SHORT	 mute=1;
 SHORT   stereo=1;
 ULONG   freq=0;
 ULONG   f=7800;
 int     i;
 char	 buf[80];
 char    *buff=buf;
// int     isster,istune;  /* undoc for get stereo/tune */

// get defaults from user.ini
 Parmlen=sizeof(mute);
 PrfQueryProfileData(HINI_USERPROFILE,"Radio","Mute",&mute,&Parmlen);
 Parmlen=sizeof(stereo);
 PrfQueryProfileData(HINI_USERPROFILE,"Radio","Stereo",&stereo,&Parmlen);
 Parmlen=sizeof(f);
 PrfQueryProfileData(HINI_USERPROFILE,"Radio","Frequency",&f,&Parmlen);
 freq=f*10;
// get cmdline parameters
 if (argc>1)
   for(i=1; i<argc; ++i)
   {
      buff=argv[i];
      buff=strupr(buff);
      if (strcmp(buff,"STEREO")==0) { stereo=1; continue; }
      if (strcmp(buff,"MONO")==0) { stereo=0; continue; }
      if (strcmp(buff,"ON")==0) { mute=1; continue; }
      if (strcmp(buff,"OFF")==0) { mute=0; continue; }
      f=(atof(buff)*1000);
      if (f!=0) freq=f;
   }

// open radio driver
 DosOpen( "RADIO$",&DevHandle,&Action,0,FILE_NORMAL,FILE_OPEN,
	  OPEN_ACCESS_READWRITE | OPEN_SHARE_DENYNONE,NULL);

/******** demo of get stereo/tuned
// test for stereo
 Parmlen=0;
 DosDevIOCtl( DevHandle,0x80,IS_STEREO,NULL,0,NULL,
	(PULONG) &Data,sizeof(Data),(PULONG) &Parmlen);
 isster=Data[0];

// test for tuned
 Parmlen=0;
 DosDevIOCtl( DevHandle,0x80,IS_TUNE,NULL,0,NULL,
	(PULONG) &Data,sizeof(Data),(PULONG) &Parmlen);
 istune=Data[0];
*********/

// send frequency
 Parmlen=4;
 Freq[0]=freq;
 if (freq!=0)
	DosDevIOCtl( DevHandle,0x80,SET_FREQ,(PULONG) &Freq,
	sizeof(Freq),(PULONG) &Parmlen,NULL,0,NULL);

// send stereo on/off
 Data[0]=stereo;
 Parmlen=2;
 DosDevIOCtl( DevHandle,0x80,SET_STEREO,(PULONG) &Data,
	sizeof(Data),(PULONG) &Parmlen,NULL,0,NULL);

// send radio on/off (mute)
 Data[0]=mute;
 Parmlen=2;
 DosDevIOCtl( DevHandle,0x80,SET_MUTE,(PULONG) &Data,
	sizeof(Data),(PULONG) &Parmlen,NULL,0,NULL);

// save new defaults in user.ini
 PrfWriteProfileData(HINI_USERPROFILE,"Radio","Mute",&mute,sizeof(mute));
 PrfWriteProfileData(HINI_USERPROFILE,"Radio","Stereo",&stereo,sizeof(stereo));
 PrfWriteProfileData(HINI_USERPROFILE,"Radio","Frequency",&f,sizeof(f));
}

