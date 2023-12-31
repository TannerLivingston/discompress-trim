@echo off
setlocal EnableDelayedExpansion

REM Get the directory and file extention of the input file
set "input_file=%~1"
set "input_directory=%~dp1"
set "input_extension=%~x1"

REM Get user input on start and stop times
echo Enter clip start and end times in hh mm ss format
echo One or both can be ignored by pressing Enter...
echo:
set /p "start=Enter start time: "
set /p "end=Enter end time: "

set start=%start: =:%
set end=%end: =:%

REM Extract input file name without extension
for %%f in ("%input_file%") do set "input_file_name=%%~nf"

REM Name the temp file to be used for the unprocessed clip
set "temp_file_name=temp_%input_file_name%"

REM Get current date and time
for /F "tokens=1-3 delims=:." %%a in ("%time%") do (
    set "hour=%%a"
    set "minute=%%b"
    set "second=%%c"
)
set "current_time=%hour%%minute%%second%"



REM Check if input file extension is valid for video
set "video_extensions=.mp4 .avi .mkv .mov .flv .wmv .webm .mpeg .3gp"
echo %video_extensions% | find /i "%input_extension%" >nul && (
    call :trim_video
    call :process_video
    call :delete_temp_file
    goto :eof
)

REM Check if input file extension is valid for audio
set "audio_extensions=.mp3 .wav .m4a .flac .aac .ogg .wma"
echo %audio_extensions% | find /i "%input_extension%" >nul && (
    call :process_audio
    goto :eof
)

REM If input file extension is not recognized, display error message and exit
echo File type not supported.
echo Terminating compression.
pause
goto :eof

REM Function for trimming video file
:trim_video (
    echo:
    echo Trimming clip from video

    REM Use FFMPEG to trim the video clip
    pushd %input_directory%
    set "trim_command=ffmpeg -hide_banner -loglevel warning -i "%input_file%""
    set "start_arg="
    set "end_arg="
    if %start% NEQ  =: (
        set "start_arg=-ss %start%"
    )
    if %end% NEQ  =: (
        set "end_arg=-to %end%"
    )
    set "trim_command=%trim_command% %start_arg% %end_arg% -c copy "%temp_file_name%.mp4""
    %trim_command%

    REM ffmpeg -hide_banner -loglevel warning -i "%input_file%" -ss %start% -to %end% -c copy "%temp_file_name%.mp4"
    popd

    goto :eof
)

REM Function for deleting the temp file
:delete_temp_file (
    echo Removing temp file

    pushd %input_directory%
    del "%temp_file_name%.mp4"

    goto :eof
)

REM Function for processing video file
:process_video (
    echo Processing video file: %input_file%

    REM Calculate bitrate based on input file duration
    for /f "delims=" %%i in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%temp_file_name%.mp4"') do set "duration=%%i"

    set /a "bitrate=23 * 8 * 1000 / duration"
    echo Video length: %duration%s
    echo Bitrate target: %bitrate%k

    REM Exit if target bitrate is under 150kbps
    if %bitrate% LSS 150 (
    echo Target bitrate is under 150kbps.
    echo Unable to compress.
    pause
    goto :eof
    )

    REM Allocate bitrate based on video properties
    set /a "video_bitrate=bitrate * 90 / 100"
    set /a "audio_bitrate=bitrate * 10 / 100"

    echo Video Bitrate: %video_bitrate%
    echo Audio Bitrate: %audio_bitrate%



    REM Exit if target video bitrate is under 125kbps
    if %video_bitrate% LSS 125 (
        echo Target video bitrate is under 125kbps.
        echo Unable to compress.
        pause
        goto :eof
    )

    REM Exit if target audio bitrate is under 32kbps
    if %audio_bitrate% LSS 32 (
        echo Target audio bitrate is under 32.
        echo Unable to compress.
        pause
        goto :eof
    )

    pushd %input_directory%
    echo Compressing video file using FFmpeg...
    ffmpeg -hide_banner -loglevel warning -stats -threads 0 -hwaccel auto -i "%temp_file_name%.mp4" -preset slow -c:v h264_nvenc -b:v %video_bitrate%k -c:a aac -b:a %audio_bitrate%k -bufsize %bitrate%k -minrate 100 -maxrate %bitrate%k "25MB_%input_file_name%.mp4"
    popd

    goto :eof
)


REM Function for processing audio file
:process_audio (
    echo Processing audio file: %input_file%

    REM Calculate input file duration
    for /f "delims=" %%i in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%temp_file_name%.mp4"') do set "duration=%%i"

    REM Calculate target bitrate based on input file duration
    set /a "bitrate=25 * 8 * 1000 / duration"
    echo Audio duration: %duration%s
    echo Bitrate target: %bitrate%k

    REM Exit if target bitrate is under 32kbps
    if %bitrate% LSS 32 (
        echo Target bitrate is under 32kbps.
        echo Unable to compress.
        pause
        goto :eof
    )

    REM Compress audio file using FFmpeg
    pushd %input_directory%
    echo Compressing audio file using FFmpeg...
    ffmpeg -hide_banner -loglevel warning -stats -i "%temp_file_name%.mp4" -preset slow -c:a libmp3lame -b:a %bitrate%k -bufsize %bitrate%k -minrate 100 -maxrate %bitrate%k "25MB_%input_file_name%.mp3"
    popd

    goto :eof
)