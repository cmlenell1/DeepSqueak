% --- Executes on button press in multinetdect.
function multinetdect_Callback(hObject, eventdata, handles, SingleDetect)
if isempty(handles.audiofiles)
    errordlg('No Audio Selected')
    return
end
if isempty(handles.networkfiles)
    errordlg('No Network Selected')
    return
end
if exist(handles.settings.detectionfolder,'dir')==0
    errordlg('Please Select Output Folder')
    uiwait
    load_detectionFolder_Callback(hObject, eventdata, handles)
    handles = guidata(hObject);  % Get newest version of handles
end

%% Do this if button Multi-Detect is clicked
if ~SingleDetect
    audioselections = listdlg('PromptString','Select Audio Files:','ListSize',[500 300],'ListString',handles.audiofilesnames);
    if isempty(audioselections)
        return
    end
    networkselections = listdlg('PromptString','Select Networks (max 2):','ListSize',[500 300],'ListString',handles.networkfilesnames);
    if isempty(audioselections)
        return
    end
    
    % Only two networks are allowed at a time.
    if length(networkselections) > 2
        errordlg(sprintf('It is illegal to use more than two networks simultaneously.\nIf you must, you may manually merge detection files'));
        uiwait
        networkselections = listdlg('PromptString','Select Networks:','ListSize',[500 300],'ListString',handles.networkfilesnames);
        if length(networkselections) > 2
            errordlg(sprintf('If you need more than two networks, you are probably doing something wrong'));
            uiwait
            networkselections = listdlg('PromptString','Select Networks:','ListSize',[500 300],'ListString',handles.networkfilesnames);
            if length(networkselections) > 2
                errordlg(sprintf('Why are you doing this? Please Stop!'));
                uiwait
                networkselections = listdlg('PromptString','Select Networks:','ListSize',[500 300],'ListString',handles.networkfilesnames);
                if length(networkselections) > 2
                    errordlg(sprintf('Ok, but its not going to work'));
                    uiwait
                end
            end
        end
    end
    %% Do this if button Single-Detect is clicked
elseif SingleDetect
    audioselections = get(handles.AudioFilespopup,'Value');
    networkselections = get(handles.neuralnetworkspopup,'Value');
end

Settings = [];
for k=1:length(networkselections)
    prompt = {'Total Analysis Length (Seconds; 0 = Full Duration)','Analysis Chunk Length (Seconds; GPU Dependent)','Overlap (Seconds)','Frequency Cut Off High (kHZ)','Frequency Cut Off Low (kHZ)','Score Threshold (0-1)','Power Threshold (0-10)','Append Date to FileName (1 = yes)','Spectrogram Gain'};
    dlg_title = ['Settings for ' handles.networkfiles(networkselections(k)).name];
    num_lines=[1 100]; options.Resize='off'; options.WindowStyle='modal'; options.Interpreter='tex';
    def = handles.settings.detectionSettings;
    Settings = [Settings str2double(inputdlg(prompt,dlg_title,num_lines,def,options))];
    
    if isempty(Settings) % Stop if user presses cancel
        return
    end
    
    % Save new settings
    handles.settings.detectionSettings = sprintfc('%g',Settings(:,1))';
    settings = handles.settings;
    save([handles.squeakfolder '/settings.mat'],'-struct','settings')
    update_folders(hObject, eventdata, handles);
    handles = guidata(hObject);  % Get newest version of handles
end
if isempty(Settings)
    return
end


%% For Each File
for j = 1:length(audioselections)
    CurrentAudioFile = audioselections(j);
    % For Each Network
    for k=1:length(networkselections)
        h = waitbar(0,'Loading neural network...');

        AudioFile = fullfile(handles.audiofiles(CurrentAudioFile).folder,handles.audiofiles(CurrentAudioFile).name);
        % cd(handles.settings.detectionfolder);
        networkname = handles.networkfiles(networkselections(k)).name;
        networkpath = fullfile(handles.networkfiles(networkselections(k)).folder,networkname);
        NeuralNetwork=load(networkpath);%get currently selected option from menu
        close(h);
        if k==1
            Calls1=SqueakDetect(AudioFile,NeuralNetwork,handles.audiofiles(CurrentAudioFile).name,Settings(:,k),0,0,j,length(audioselections),networkname);
        elseif k==2
            Calls2=SqueakDetect(AudioFile,NeuralNetwork,handles.audiofiles(CurrentAudioFile).name,Settings(:,k),0,0,j,length(audioselections),networkname);
        end
    end
    
    
    %% Save the file
    h = waitbar(1,'Saving...');
    
    [~,audioname] = fileparts(AudioFile);
    detectiontime=datestr(datetime('now'),'mmm-DD-YYYY HH_MM PM');
    
    % Append date to filename
    if Settings(8)
        fname = fullfile(handles.settings.detectionfolder,[audioname ' ' detectiontime '.mat']);
    else
        fname = fullfile(handles.settings.detectionfolder,audioname);
    end
    
    if length(networkselections)==1
        if ~isempty(Calls1)
            Calls=Calls1;
        else
            disp(['No calls detected in: ' audioname]);
            continue
        end           
    end
    
    if length(networkselections)==2
        if ~isempty(Calls1) &  ~isempty(Calls2)
            Calls = Automerge_Callback(Calls1,Calls2,AudioFile);
        elseif ~isempty(Calls1)
            Calls=Calls1;
        elseif ~isempty(Calls2)
            Calls=Calls2;
        else
            disp(['No calls detected in: ' audioname]);
            continue
        end
    end
    
    save(fname,'Calls','settings','AudioFile','detectiontime','networkpath','-v7.3','-mat');
    
    delete(h)
end
update_folders(hObject, eventdata, handles);
guidata(hObject, handles);
