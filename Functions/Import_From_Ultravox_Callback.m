% --------------------------------------------------------------------
function Import_From_Ultravox_Callback(hObject, eventdata, handles)

[ultravoxName,ultravoxPath] = uigetfile([handles.squeakfolder '/*.txt'],'Select Ultravox Log');
[audioname, audiopath] = uigetfile({'*.wav;*.flac;*.UVD' 'Audio File';'*.wav' 'WAV(*.wav)'; '*.flac' 'FLAC (*.flac)'; '*.UVD' 'Ultravox File (*.UVD)'},'Select Audio File',handles.settings.audiofolder);
AudioFile = fullfile(audiopath,audioname);


% Convert from unicode to ascii
fin = fopen(fullfile(ultravoxPath,ultravoxName),'r');
chars = fscanf(fin,'%c');
chars(1:2) = [];
chars(chars == 0) = [];
chars = strrep(chars,',','.');
fin2 = fopen(fullfile(ultravoxPath,'temp.txt'),'w');
fwrite(fin2, chars, 'uchar');
fclose('all');

% Read file as a table
ultravox = readtable(fullfile(ultravoxPath,'temp.txt'),'Delimiter',';','ReadVariableNames',1,'HeaderLines',0);

% The Ultravox table only contains the frequency at max amplitude, so we
% need to specify the bandwidth.
CallBandwidth = inputdlg('Enter call bandwidth (kHz), because Ultravox doesn''t include it in the output file ','Import from Ultravox', [1 50],{'30'});
if isempty(CallBandwidth); return; end
CallBandwidth = str2double(CallBandwidth);

info = audioinfo(AudioFile);
rate = info.SampleRate;
Calls = struct('Rate',struct,'Box',struct,'RelBox',struct,'Score',struct,'Audio',struct,'Accept',struct,'Type',struct,'Power',struct);
hc = waitbar(0,'Importing Calls from Ultravox Log');

for i=1:length(ultravox.Call)
    waitbar(i/length(ultravox.Call),hc);
    
    Calls(i).Rate = rate;

    Calls(i).Box = [
        ultravox.StartTime_s_(i),...
        (ultravox.FreqAtMaxAmp_Hz_(i)/1000) - CallBandwidth / 2,...
        ultravox.StopTime_s_(i) - ultravox.StartTime_s_(i),...
        CallBandwidth];
    
    Calls(i).RelBox=[
        (ultravox.Duration_ms_(i) / 1000),...
        (ultravox.FreqAtMaxAmp_Hz_(i)/1000) - CallBandwidth / 2,...
        (ultravox.Duration_ms_(i) / 1000),...
        CallBandwidth];
    
    Calls(i).Score = 1;
  
    windL = ultravox.StartTime_s_(i) - (ultravox.Duration_ms_(i) / 1000);
    if windL < 0
        windL = 1 / rate;
    end
    windR = ultravox.StopTime_s_(i) + (ultravox.Duration_ms_(i) / 1000);
    
    Calls(i).Audio=audioread(AudioFile,round([windL windR]*rate),'native');
    Calls(i).Accept=1;
    Calls(i).Type=categorical(ultravox.CallName(i));
    Calls(i).Power = 0;
end
close(hc);


[FileName,PathName] = uiputfile([handles.settings.detectionfolder '/*.mat'],'Save Call File');
filename = fullfile(PathName,FileName);


Calls = Automerge_Callback(Calls,[],AudioFile);
h = waitbar(.9,'Saving Output Structures');
detectiontime=datestr(datetime('now'),'mmm-DD-YYYY HH_MM PM');
save(filename,'Calls','AudioFile','detectiontime','-v7.3');

close(h);


update_folders(hObject, eventdata, handles);
handles = guidata(hObject);  % Get newest version of handles


