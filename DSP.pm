package Audio::DSP;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
@EXPORT = qw();
$VERSION = '0.01';

bootstrap Audio::DSP $VERSION;

1;
__END__

=head1 NAME

Audio::DSP - Perl interface to *NIX digital audio device.

=head1 SYNOPSIS

    use Audio::DSP;

    ($buf, $chan, $fmt, $rate) = (4096, 1, 8, 8192);

    $dsp = new Audio::DSP(buffer   => $buf,
                          channels => $chan,
                          format   => $fmt,
                          rate     => $rate);

    $seconds = 5;
    $length  = ($chan * $fmt * $rate * $seconds) / 8;

    $dsp->init() || die $dsp->errstr();

    # Record 5 seconds of sound
    for (my $i = 0; $i < $length; $i += $buf) {
        $dsp->read() || die $dsp->errstr();
    }

    # Play it back
    for (;;) {
        $dsp->write() || last;
    }

    $dsp->close();

=head1 DESCRIPTION

Audio::DSP is built around the OSS (Open Sound System) API and allows perl to
interface with a digital audio device. The Audio::DSP object stores I/O
parameters and also supplies temporary storage for raw audio data.

In order to use Audio::DSP, you'll need to have the necessary OSS
drivers/includes installed. OSS is available for many popular Unices, and a
GPLed version (with which this extension was developed and tested) is
distributed with with the Linux kernel.

=head1 CONSTRUCTOR

=over 4

=item new([params])

Returns new Audio::DSP object. Parameters:

=over 4

=item device

Name of audio device file. Default is "/dev/dsp".

=item buffer

Length of buffer, in bytes, for reading from/writing to the audio device file.
Default is 4096.

=item rate

Sampling rate in bytes per second. Default is 8192.

=item format

Sample format. This parameter affects not only the size and the byte-order of
a sample, but also its dynamic range.

Sample format may be specified as an integer (e.g. 8 or 16) or as a string
corresponding to the formats defined in "#soundcard.h". The latter is
preferred; an integer value of 16 (for example) corresponds to little endian
signed 16 (AFMT_S16_LE), which format may or may not work with your card. So be
careful. Formats are:

=over 4

=item AFMT_QUERY

Used to query current audio format, and useless in this context. See the
L<Audio::DSP::queryformat|"item_queryformat"> method for getting the currently
used format of an initialized audio device.

=item AFMT_MU_LAW

logarithmic mu-Law

=item AFMT_A_LAW

logarithmic A-Law

=item AFMT_IMA_ADPCM

4:1 compressed (IMA)

=item AFMT_U8

8 bit unsigned

=item AFMT_S16_LE

16 bit signed little endian (Intel - used in PC soundcards)

=item AFMT_S16_BE

16 bit signed big endian (PPC, Sparc, etc)

=item AFMT_S8

8 bit signed

=item AFMT_U16_LE

16 bit unsigned little endian

=item AFMT_U16_BE

16 bit unsigned bit endian

=item AFMT_MPEG

MPEG (currently not supported by OSS)

=back

Default is AFMT_U8.

=item channels

1 (mono) or 2 (stereo). Default is 1.

=item file

File from which to read raw sound data to be stored in the Audio::DSP object.

No effort is made to interpret the type of file being read. It's up
to you to set the appropriate rate, channel, and format parameters if you
wish to write the sound data to your audio device without damaging your
hearing.

=back

=back

=head1 METHODS

=over 4

=item audiofile($filename)

Reads data from specified file and stores it in the Audio::DSP object. If there
is already sound data stored in the object, the file data will be concatenated
onto the end of it.

No effort is made to interpret the type of file being read. It's up
to you to set the appropriate rate, channel, and format parameters if you
wish to write the sound data to your audio device without damaging your
hearing.

    $dsp->audiofile("foo.raw") || die $dsp->errstr();

Returns true on success, false on error.

=item clear()

Clears audio data currently stored in Audio::DSP object, sets play mark to
zero. No return value.

=item close()

Closes audio device file. Returns true on success, false on error.

=item data()

Returns sound data stored in Audio::DSP object.

    open RAWFILE, ">foo.raw";
    print RAWFILE $dsp->data();
    close RAWFILE;

=item datacat($data)

Concatenates argument (a string) to audio data stored in Audio::DSP object.
Returns length of audio data currently stored.

=item datalen()

Returns length of audio data currently stored in Audio::DSP object.

=item errstr()

Returns last recorded error.

=item getformat($format)

Returns true if specified L<sample format|"item_format"> is supported by audio
device. A false value may indicate the format is not supported, but it may also
mean that the SNDCTL_DSP_GETFMTS ioctl failed (the
L<Audio::DSP::init|"item_init"> method must be called before this method), etc.
Be sure to check the last L<error message|"item_errstr"> in this case.

=item init([params])

Opens and initializes audio device file. Parameters L<device|"item_device">,
L<buffer|"item_buffer">, L<rate|"item_rate">, L<format|"item_format">, and
L<channels|"item_channels"> are shared with the constructor, and will override
them. Other parameters:

=over 4

=item mode

Mode in which to open audio device file. Accepted values:

    "O_RDONLY" (read-only)
    "O_WRONLY" (write-only)
    "O_RDWR" (read-write)

The default value is "O_RDWR".

=back

Example:

    $dsp->init(mode => "O_RDONLY") || die $dsp->errstr();

Returns true on success, false on error.

=item post()

Sends SNDCTL_DSP_POST ioctl message to audio device file. Returns true on
success, false on error. The L<Audio::DSP::init|"item_init"> method must be
called before this method.

=item queryformat()

Returns currently used format of initialized audio device. Unlike the
L<Audio::DSP::setformat|"item_setformat"> method, queryformat "asks" the audio
device directly which format is being used. The L<Audio::DSP::init|"item_init">
method must be called before this method.

=item read()

Reads buffer length of data from audio device file and appends it to the
audio data stored in Audio::DSP object. Returns true on success, false on
error.

=item setbuffer([$length])

Sets read/write buffer if argument is provided.

Returns buffer length currently set in Audio::DSP object.

=item setrate([$rate])

Sets number of channels if argument is provided. If the audio device file is
open, the number of channels will not actually be changed until you call
close() and init() again.

Returns number of channels currently set in Audio::DSP object.

=item setdevice([$device_name])

Sets audio device file if argument is provided. If the device is open, it will
not actually be changed until you call close() and init() again.

Returns audio device file name currently set in Audio::DSP object.

=item setformat([$bits])

Sets sample format if argument is provided. If the audio device file is open,
the sample format will not actually be changed until you call close() and
init() again.

Returns sample format currently set in Audio::DSP object.

=item setmark([$mark])

Sets play mark if argument is provided. The play mark indicates how many bites
of audio data stored in the Audio::DSP object have been written to the audio
device file since the mark was last set to zero. This lets the
L<Audio::DSP::write|"item_write"> method know what to write.

Returns current play mark.

=item setrate([$rate])

Sets sample rate if argument is provided. If the audio device file is open,
the sample rate will not actually be changed until you call close() and
init() again.

Returns sample rate currently set in Audio::DSP object.

=item sync()

Sends SNDCTL_DSP_SYNC ioctl message to audio device file. Returns true on
success, false on error. The L<Audio::DSP::init|"item_init"> method must be
called before this method.

=item write()

Writes buffer length of sound data currently stored in Audio::DSP object,
starting at the current L<play mark|"item_setmark"> offset, to audio device
file. L<Play mark|"item_setmark"> is incremented one buffer length. Returns
true on success, false on error or if the L<play mark|"item_setmark"> exceeds
the length of audio data stored in the Audio::DSP object.

=back

=head1 NOTES

Audio::DSP does not provide any methods for converting the raw audio data
stored in its object into other formats (that's another project altogether).
You can, however, use the L<Audio::DSP::data|"item_data"> method to dump the
raw audio to a file, then use a program like sox to convert it to your
favorite format. If you are interested in writing .wav files, you may want to
take a look at Nick Peskett's Audio::Wav module.

=head1 TO DO

Implement PerlIO.

=head1 AUTHOR

Seth David Johnson, affection@pdamusic.com

=head1 SEE ALSO

Open Sound System homepage: http://www.opensound.com/

Open Sound System - Audio programming:
http://www.opensound.com/pguide/audio.html

A GPLed version of OSS distributed with the Linux kernel was used in the
development of Audio::DSP. See "The Linux Sound System":
http://www.linux.org.uk/OSS/

For those curious, the Advanced Linux Sound Architecture (ALSA) API should
remain compatible with the OSS API on which this extension is built. ALSA
homepage: http://www.alsa-project.org/

perl(1).

=head1 COPYRIGHT

Copyright (c) 1999 Seth David Johnson.  All Rights Reserved. This program
is free software; you can redistribute it and/or modify it under the same 
terms as Perl itself.

=cut
