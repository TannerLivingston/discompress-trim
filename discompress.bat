@echo off
setlocal EnableDelayedExpansion

REM Get the directory and file extension of the input file
set "input_file=%~1"
set "input_directory=%~dp1"
set "input_extension=%~x1"

REM Extract input file name without extension
for %%f in ("%input_file%") do set "input_file_name=%%~nf"

REM Calculate clip duration
for /f "delims=" %%i in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%input_file%"') do set "duration=%%i"
echo Original clip duration: %duration%

REM Function to prompt the user for start time
:prompt_for_start_time
set /p "start_time=Enter start time (format: HH:MM:SS, leave blank for beginning of the video): "
set "start_time=!start_time: =:!"

REM Function to prompt the user for end time
:prompt_for_end_time
set /p "end_time=Enter end time (format: HH:MM:SS, leave blank for end of the video): "
set "end_time=!end_time: =:!"

REM Function to calculate duration and determine optimal bitrate
:calculate_bitrate

REM Adjust duration based on start and end times
if defined start_time (
    for /f "tokens=1-3 delims=:" %%a in ("%start_time%") do (
        set /a "start_seconds=(((%%a * 60) + %%b) * 60) + %%c"
    )
    if defined end_time (
        for /f "tokens=1-3 delims=:" %%a in ("%end_time%") do (
            set /a "end_seconds=(((%%a * 60) + %%b) * 60) + %%c"
        )
    ) else (
        set "end_seconds=!duration!"
    )
    set /a "duration=end_seconds - start_seconds"
)

REM If start time is provided without end time, set end time to the end of the video
if defined end_time (
    if not defined start_time (
        set "start_seconds=0"
        for /f "tokens=1-3 delims=:" %%a in ("%end_time%") do (
            set /a "end_seconds=(((%%a * 60) + %%b) * 60) + %%c"
        )
        set /a "duration=end_seconds"
    )
)

REM Calculate target bitrate based on clip duration
set /a "bitrate=25 * 8 * 1000 / duration"
echo Clip duration: %duration%s
echo Target bitrate: %bitrate%k

REM Check if the target bitrate is under 150kbps
if %bitrate% LSS 150 (
    echo Target bitrate is under 150kbps.
    echo Unable to compress.
    pause
    goto :eof
)

REM Calculate video and audio bitrates
set /a "video_bitrate=bitrate * 90 / 100"
set /a "audio_bitrate=bitrate * 10 / 100"

REM Check if the video bitrate is under 125kbps
if %video_bitrate% LSS 125 (
    echo Target video bitrate is under 125kbps.
    echo Unable to compress.
    pause
    goto :eof
)

REM Check if the audio bitrate is under 32kbps
if %audio_bitrate% LSS 32 (
    echo Target audio bitrate is under 32kbps.
    echo Unable to compress.
    pause
    goto :eof
)

REM Function to trim and compress video using FFmpeg
:trim_and_compress_video
echo Trimming and compressing video file: %input_file%
set "output_file=25MB_%input_file_name%.mp4"
pushd %input_directory%
set "ffmpeg_command=ffmpeg -hide_banner -loglevel warning -stats"

REM Add start time parameter if provided
if defined start_time (
    set "ffmpeg_command=!ffmpeg_command! -ss %start_time%"
)

REM Add end time parameter if provided
if defined end_time (
    set "ffmpeg_command=!ffmpeg_command! -to %end_time%"
)

set "ffmpeg_command=!ffmpeg_command! -i "%input_file%" -preset slow -c:v h264_nvenc -b:v %video_bitrate%k -c:a aac -b:a %audio_bitrate%k -bufsize %bitrate%k -minrate 100 -maxrate %bitrate%k "%output_file%"
echo %ffmpeg_command%
!ffmpeg_command!
popd
echo Compression complete. Output file: %output_file%
goto :eof


REM Check if input file extension is valid for video
set "video_extensions=.mp4 .avi .mkv .mov .flv .wmv .webm .mpeg .3gp"
echo %video_extensions% | find /i "%input_extension%" >nul && (
    call :prompt_for_start_time
    call :prompt_for_end_time
    call :calculate_bitrate
    call :trim_and_compress_video
    goto :eof
)

REM If input file extension is not recognized, display error message and exit
echo File type not supported.
echo Terminating compression.
pause
goto :eof
