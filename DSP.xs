#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/soundcard.h>

#define AUDIO_FILE_BUFFER_SIZE 4096 /* this is totally arbitrary */

int audioformat (SV* fmt) {
    char* val;

    /* format specified as integer */
    if (SvIOK(fmt))
        return (SvIV(fmt));

    /* format specified as string */
    else if (SvPOK(fmt)) {
        val = SvPVX(fmt);

        if (strEQ(val, "AFMT_QUERY"))
            return(AFMT_QUERY);
        else if (strEQ(val, "AFMT_MU_LAW"))
            return(AFMT_MU_LAW);
        else if (strEQ(val, "AFMT_A_LAW"))
            return(AFMT_A_LAW);
        else if (strEQ(val, "AFMT_IMA_ADPCM"))
            return(AFMT_IMA_ADPCM);
        else if (strEQ(val, "AFMT_U8"))
            return(AFMT_U8);
        else if (strEQ(val, "AFMT_S16_LE"))
            return(AFMT_S16_LE);
        else if (strEQ(val, "AFMT_S16_BE"))
            return(AFMT_S16_BE);
        else if (strEQ(val, "AFMT_S8"))
            return(AFMT_S8);
        else if (strEQ(val, "AFMT_U16_LE"))
            return(AFMT_U16_LE); 
        else if (strEQ(val, "AFMT_U16_BE"))
            return(AFMT_U16_BE);
        else if (strEQ(val, "AFMT_MPEG"))
            return(AFMT_MPEG);
        else {
            /* croak("unrecognized format %s", fmt); */
            return(-1);
        }
    } else {
           /* croak("format neither int nor string"); */
           return(-1);
   }
}

MODULE = Audio::DSP		PACKAGE = Audio::DSP		

PROTOTYPES: DISABLED

void
new (...)
    PPCODE:
    {
        HV* construct      = newHV(); /* what the Audio::DSP object references */
        HV* param          = newHV(); /* for storing parameters */
        HV* thistash       = newHV(); /* erm... this stash */

        SV* buff           = newSViv(4096);    /* read/write buffer */
        SV* chan           = newSViv(1);       /* mono(1) or stereo(2) */
        SV* data           = newSVpv("",0);    /* stored audio data */
        SV* datalen        = newSViv(0);       /* length of stored audio data */
        SV* device         = newSVpv("/dev/dsp",8);
        SV* error_string   = newSVpvf("",0);
        SV* file_indicator = newSViv(0);       /* a file descriptor for now... */
        SV* format         = newSViv(AFMT_U8); /* 8 bit unsigned is default */
        SV* mark           = newSViv(0);       /* play position */
        SV* rate           = newSViv(8192);    /* sampling rate */
        SV* self;

        char  audio_buff[AUDIO_FILE_BUFFER_SIZE];
        char* audio_file; /* if "file" param exists */
        char* key;        /* param name */

        int audio_fd;
        int klength;  /* param name length */
        int status;
        int stidx;    /* stack index */

        /* Store parameters in hash */
        for (stidx = items % 2; stidx < items; stidx += 2) {
            key     = SvPVX(ST(stidx));
            klength = SvCUR(ST(stidx));
            hv_store(param, key, klength, ST((stidx) + 1), 0);
        }

        /******** use parameters if present ********/
        if (hv_exists(param, "device", 6))
            sv_setpv(device, SvPVX(*hv_fetch(param, "device", 6, 0)));

        if (hv_exists(param, "buffer", 6))
            sv_setiv(buff, SvIV(*hv_fetch(param, "buffer", 6, 0)));

        if (hv_exists(param, "rate", 4))
            sv_setiv(rate, SvIV(*hv_fetch(param, "rate", 4, 0)));

        if (hv_exists(param, "format", 6)) {
            sv_setiv(format, audioformat(*hv_fetch(param, "format", 6, 0)));
            if (SvIV(format) < 0)
                croak("error determining audio format");
        }

        if (hv_exists(param, "channels", 8))
            sv_setiv(chan, SvIV(*hv_fetch(param, "channels", 8, 0)));

        /**** store data from existing audio file ****/
        if (hv_exists(param, "file", 4)) {
            audio_file = SvPVX(*hv_fetch(param, "file", 4, 0));

            audio_fd = open(audio_file, O_RDONLY);
            if (audio_fd < 0)
                croak("failed to open %s", audio_file);

            for (;;) {
                status = read(audio_fd, audio_buff, AUDIO_FILE_BUFFER_SIZE);
                if (status == 0)
                    break;
                else
                    sv_catpvn(data, audio_buff, status);
            }

            if (close(audio_fd) < 0)
                croak("problem closing audio file %s", audio_file);

            /* get size of audio data currently stored */
            sv_setiv(datalen, SvCUR(data));
        }

        /******** assign settings to new object ********/
        hv_store(construct, "buffer", 6, buff, 0);
        hv_store(construct, "channels", 8, chan, 0);
        hv_store(construct, "data", 4, data, 0);
        hv_store(construct, "datalen", 7, datalen, 0);
        hv_store(construct, "device", 6, device, 0);
        hv_store(construct, "error_string", 12, error_string, 0);
        hv_store(construct, "file_indicator", 14, file_indicator, 0);
        hv_store(construct, "format", 6, format, 0);
        hv_store(construct, "mark", 4, mark, 0);
        hv_store(construct, "rate", 4, rate, 0);

        self = newRV_inc((SV*)construct); /* make a reference */
        thistash = gv_stashpv("Audio::DSP", 0);
        sv_bless(self, thistash);         /* bless it */
        XPUSHs(self);                     /* push it */
    }

void
audiofile (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        char audio_buff[AUDIO_FILE_BUFFER_SIZE];
        char* audio_file;
        int audio_fd;
        int status;

        audio_file = SvPVX(ST(1));
        audio_fd   = open(audio_file, O_RDONLY);

        if (audio_fd < 0) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("failed to open audio file '%s'", audio_file), 0);
            XSRETURN_NO;
        }

        for (;;) {
            status = read(audio_fd, audio_buff, AUDIO_FILE_BUFFER_SIZE);
            if (status == 0)
                break;
            else
                sv_catpvn(*hv_fetch(caller, "data", 4, 0), audio_buff, status);
        }

        if (close(audio_fd) < 0) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("problem closing audio file '%s'", audio_file), 0);
            XSRETURN_NO;
        }

        /* get size of audio data currently stored */
        hv_store(caller, "datalen", 7,
                 newSViv(SvCUR(*hv_fetch(caller, "data", 4, 0))), 0);
        XSRETURN_YES;
    }

void
init (...)
    PPCODE:
    {
        SV* format;

        HV* caller = (HV*)SvRV(ST(0));
        HV* param  = newHV();

        char* dev;
        char* key;
        char* val;

        int arg;
        int fd;
        int klength;
        int mode;  /* device open mode */
        int status;
        int stidx;

        if ((items % 2) == 0)
            croak("Odd number of elements in hash list");

        /* Store parameters in hash */
        for (stidx = 1; stidx < items; stidx += 2) {
            key     = SvPVX(ST(stidx));
            klength = SvCUR(ST(stidx));
            hv_store(param, key, klength, ST((stidx) + 1), 0);
        }

        /******** check for param, store in Audio::DSP object ********/
        if (hv_exists(param, "device", 6))
            hv_store(caller, "device", 6,
                     *hv_fetch(param, "device", 6, 0), 0);

        if (hv_exists(param, "buffer", 6))
            hv_store(caller, "buffer", 6,
                     *hv_fetch(param, "buffer", 6, 0), 0);

        if (hv_exists(param, "rate", 4))
            hv_store(caller, "rate", 4,
                     *hv_fetch(param, "rate", 4, 0), 0);

        if (hv_exists(param, "format", 6)) {
            hv_store(caller, "format", 6,
                     newSViv(audioformat(*hv_fetch(param, "format", 6, 0))), 0);
            if (SvIV(*hv_fetch(caller, "format", 6, 0)) < 0) {
                hv_store(caller, "error_string", 12,
                         newSVpvf("error determining audio format"), 0);
                XSRETURN_NO;
            }
        }

        if (hv_exists(param, "channels", 8))
            hv_store(caller, "channels", 8,
                     *hv_fetch(param, "channels", 8, 0), 0);

        /******** get file mode ********/
        if (hv_exists(param, "mode", 4)) {
 
            /* mode specified as integer (why?) */
            if (SvIOK(*hv_fetch(param, "mode", 4, 0)))
                mode = SvIV(*hv_fetch(param, "mode", 4, 0));
 
            /* mode specified as string (flag) */
            else if (SvPOK(*hv_fetch(param, "mode", 4, 0))) {
                val = SvPVX(*hv_fetch(param, "mode", 4, 0));

                if (strEQ(val, "O_RDONLY"))
                    mode = O_RDONLY;
                else if (strEQ(val, "O_WRONLY"))
                    mode = O_WRONLY;
                else if (strEQ(val, "O_RDWR"))
                    mode = O_RDWR;
                else {
                    hv_store(caller, "error_string", 12,
                             newSVpvf("unrecognized open flag"), 0);
                    XSRETURN_NO;
                }

            /* what on earth did you send me? */
            } else {
                hv_store(caller, "error_string", 12,
                         newSVpvf("mode neither int nor string"), 0);
                XSRETURN_NO;
            }

        /* hmm... I'll just open it read/write */
        } else
            mode = O_RDWR;

        /**** device name ****/
        dev = SvPVX(*hv_fetch(caller, "device", 6, 0));

        /**** open device ****/
        fd = open(dev, mode);
        if (fd < 0) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("failed to open device '%s'", dev), 0);
            XSRETURN_NO;
        }

        /**** set sampling format ****/
        arg = SvIV(*hv_fetch(caller, "format", 6, 0));

        if (ioctl(fd, SNDCTL_DSP_SETFMT, &arg) == -1) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("SNDCTL_DSP_SETFMT ioctl failed"), 0);
            XSRETURN_NO;
        }
        if (arg != SvIV(*hv_fetch(caller, "format", 6, 0))) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("failed to set sample format"), 0);
            XSRETURN_NO;
        }

        /**** set channels ****/
        arg    = SvIV(*hv_fetch(caller, "channels", 8, 0));
        if (ioctl(fd, SNDCTL_DSP_CHANNELS, &arg) == -1) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("SNDCTL_DSP_CHANNELS ioctl failed"), 0);
            XSRETURN_NO;

        }
        if (arg != SvIV(*hv_fetch(caller, "channels", 8, 0))) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("failed to set number of channels"), 0);
            XSRETURN_NO;
        }
         
        /**** set sampling rate ****/
        arg = SvIV(*hv_fetch(caller, "rate", 4, 0));
        if (ioctl(fd, SNDCTL_DSP_SPEED, &arg) == -1) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("SNDCTL_DSP_SPEED ioctl failed"), 0);
            XSRETURN_NO;
        }
         
        /**** store file descriptor in Audio::DSP object ****/
        hv_store(caller, "file_indicator", 14, newSViv(fd), 0);

        XSRETURN_YES;
    }

void
close (...)
    PPCODE:
    {
        /* fetch file descriptor and close... nothing fancy */
        int fd = SvIV(*hv_fetch((HV*)SvRV(ST(0)), "file_indicator", 14, 0));

        if (close(fd) < 0)
            XSRETURN_NO;
        else
            XSRETURN_YES;
    }

void
read (...)
    PPCODE:
    {
        /* read one buffer length of data */
        HV* caller = (HV*)SvRV(ST(0));
        int count  = SvIV(*hv_fetch(caller, "buffer", 6, 0));
        int fd     = SvIV(*hv_fetch(caller, "file_indicator", 14, 0));
        int status;
        char buf[count];

        status = read(fd, buf, count); /* record some sound */
        if (status != count) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("failed to read correct number of bytes"), 0);
            XSRETURN_NO;
        }

        sv_catpvn(*hv_fetch(caller, "data", 4, 0), buf, status);
        hv_store(caller, "datalen", 7,
                 newSViv(SvCUR(*hv_fetch(caller, "data", 4, 0))), 0);
        XSRETURN_YES;
    }

void
write (...)
    PPCODE:
    {
        HV* caller  = (HV*)SvRV(ST(0));
        int count   = SvIV(*hv_fetch(caller, "buffer", 6, 0));
        int dlength = SvIV(*hv_fetch(caller, "datalen", 7, 0));
        int fd      = SvIV(*hv_fetch(caller, "file_indicator", 14, 0));
        int mark    = SvIV(*hv_fetch(caller, "mark", 4, 0));
        int status;
        char* data;

        if (mark >= dlength) /* end of data */
            XSRETURN_NO;

        data = SvPVX(*hv_fetch(caller, "data", 4, 0));

        status = write(fd, &data[mark], count);

        /*** This just causes unnecessary problems...
         * if (status != count) {
         *   hv_store(caller, "error_string", 12,
         *            newSVpvf("failed to write correct number of bytes"), 0);
         *   XSRETURN_NO;
         * }
         */

        hv_store(caller, "mark", 4, newSViv(mark + count), 0);
        XSRETURN_YES;
    }

void
post (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        int fd = SvIV(*hv_fetch(caller, "file_indicator", 14, 0));

        if (ioctl(fd, SNDCTL_DSP_POST, 0) == -1) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("SNDCTL_DSP_POST ioctl failed"), 0);
            XSRETURN_NO;
        }
        XSRETURN_YES;
    }

void
reset (...)
    PPCODE:
    {
        /************ undocumented, and useless ***********\
        \****** since init/close take care of resets ******/
        HV* caller = (HV*)SvRV(ST(0));
        int fd = SvIV(*hv_fetch(caller, "file_indicator", 14, 0));

        if (ioctl(fd, SNDCTL_DSP_RESET, 0) == -1) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("SNDCTL_DSP_RESET ioctl failed"), 0);
            XSRETURN_NO;
        }
        XSRETURN_YES;
    }

void
sync (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        int fd = SvIV(*hv_fetch(caller, "file_indicator", 14, 0));

        if (ioctl(fd, SNDCTL_DSP_SYNC, 0) == -1) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("SNDCTL_DSP_SYNC ioctl failed"), 0);
            XSRETURN_NO;
        }
        XSRETURN_YES;
    }

void
queryformat (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        int fd     = SvIV(*hv_fetch(caller, "file_indicator", 14, 0));
        int status = ioctl(fd, SNDCTL_DSP_SETFMT, AFMT_QUERY);
        XPUSHs(newSViv(status));
    }

void
getformat (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        SV* format = ST(1);
        int arg    = audioformat(format);
        int fd     = SvIV(*hv_fetch(caller, "file_indicator", 14, 0));
        int mask;

        if (arg < 0) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("error determining audio format"), 0);
            XSRETURN_NO;
        }

        if (ioctl(fd, SNDCTL_DSP_GETFMTS, &mask) == -1) {
            hv_store(caller, "error_string", 12,
                     newSVpvf("SNDCTL_DSP_GETFMTS ioctl failed"), 0);
            XSRETURN_NO;
        } else if (mask & arg) /* the format is supported */
            XSRETURN_YES;
        else
            hv_store(caller, "error_string", 12,
                     newSVpvf("format not supported"), 0);
            XSRETURN_NO;
    }

void
clear (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        hv_store(caller, "data", 4, newSVpv("",0), 0);
        hv_store(caller, "datalen", 7, newSViv(0), 0);
        hv_store(caller, "mark", 4, newSViv(0), 0);
    }

void
data (...)
    PPCODE:
    {
        XPUSHs(*hv_fetch((HV*)SvRV(ST(0)), "data", 4, 0));
    }

void
datalen (...)
    PPCODE:
    {
        XPUSHs(*hv_fetch((HV*)SvRV(ST(0)), "datalen", 7, 0));
    }

void
errstr (...)
    PPCODE:
    {
        XPUSHs(*hv_fetch((HV*)SvRV(ST(0)), "error_string", 12, 0));
    }

void
setbuffer (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        if (items >= 2) {
            SvREFCNT_inc(ST(1));
            hv_store(caller, "buffer", 6, ST(1), 0);
        }
        XPUSHs(*hv_fetch(caller, "buffer", 6, 0));
    }

void
setdevice (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        if (items >= 2) {
            SvREFCNT_inc(ST(1));
            hv_store(caller, "device", 6, ST(1), 0);
        }
        XPUSHs(*hv_fetch(caller, "device", 6, 0));
    }

void
setformat (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));

        if (items >= 2) {
            SvREFCNT_inc(ST(1));
            hv_store(caller, "format", 6, newSViv(audioformat(ST(1))), 0);
            if (SvIV(*hv_fetch(caller, "format", 6, 0)) < 0) {
                hv_store(caller, "error_string", 12,
                         newSVpvf("error determining audio format"), 0);
                XSRETURN_NO;
            }
        }

        XPUSHs(*hv_fetch(caller, "format", 6, 0));
    }

void
setmark (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        if (items >= 2) {
            SvREFCNT_inc(ST(1));
            hv_store(caller, "mark", 4, ST(1), 0);
        }
        XPUSHs(*hv_fetch(caller, "mark", 4, 0));
    }

void
setrate (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        if (items >= 2) {
            SvREFCNT_inc(ST(1));
            hv_store(caller, "rate", 4, ST(1), 0);
        }
        XPUSHs(*hv_fetch(caller, "rate", 4, 0));
    }

void
setchannels (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));
        if (items >= 2) {
            SvREFCNT_inc(ST(1));
            hv_store(caller, "channels", 8, ST(1), 0);
        }
        XPUSHs(*hv_fetch(caller, "channels", 8, 0));
    }

void
datacat (...)
    PPCODE:
    {
        HV* caller = (HV*)SvRV(ST(0));

        int dlen = SvIV(*hv_fetch(caller, "datalen", 7, 0));
        int len  = SvCUR(ST(1));

        sv_catpvn(*hv_fetch(caller, "data", 4, 0), SvPVX(ST(1)), len);
        hv_store(caller, "datalen", 7, newSViv(dlen + len), 0);
        XPUSHs(*hv_fetch(caller, "datalen", 7, 0));
    }
