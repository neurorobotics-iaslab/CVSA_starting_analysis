clc; clear all; close all;
% create the dataset according to freq selected, channels, day of log band power

%% informations
selchs = {'P3', 'PZ', 'P4', 'POZ', 'O1', 'O2', 'P5', 'P1', 'P2', 'P6', 'PO5', 'PO3', 'PO4', 'PO6', 'PO7', 'PO8', 'OZ'};
c_day = '20240515';
c_subject = 'c7';
start_cf = 1; % from which second you extract data, with 0 take the start of the trial
end_cf   = 4; % end of the trial extracted, with 0 take all the trial length
train_percentage = 0.75;

classes = [730 731];
band = [8 14];
filterOrder = 4;

% not modification needed for these informations
sampleRate = 512;
lap_path39 = '/home/paolo/laplacians/lap_39ch_CVSA.mat';
sfile = ['/home/paolo/cvsa_ws/record/dataset/' c_subject '_' c_day '_d_cf_14.mat'];

path = ['/home/paolo/cvsa_ws/record/' c_subject '/mat_selectedTrials'];
files = dir(fullfile(path, ['*' c_day '*.mat']));

channels_label = {'FP1', 'FP2', 'F3', 'FZ', 'F4', 'FC1', 'FC2', 'C3', 'CZ', 'C4', 'CP1', 'CP2', 'P3', 'PZ', 'P4', 'POZ', 'O1', 'O2', 'EOG', ...
        'F1', 'F2', 'FC3', 'FCZ', 'FC4', 'C1', 'C2', 'CP3', 'CP4', 'P5', 'P1', 'P2', 'P6', 'PO5', 'PO3', 'PO4', 'PO6', 'PO7', 'PO8', 'OZ'};

% selchs = channels_label;

%% initialization variable to save
X = [];
y = [];

info.classes = classes;
info.sampleRate = sampleRate;
info.selchs = selchs;
info.startTimeCfExtracted = start_cf;
info.files = {};
info.band = band;
info.cfStart = [];
info.cfDur = [];
info.filterOrder = 4;
info.startNewFile = [0];
info.startcf = [];

%% check the end and start of extraction
if end_cf < start_cf && end_cf ~= 0
    disp('Errore nella selezione di inizio e fine dei trials')
elseif end_cf == 0 && start_cf == 0
    disp('take all the trial')
elseif end_cf == 0
    disp(['the end is the duration of the trial but start at ' num2str(start_cf)])
elseif start_cf == 0
    disp(['the start is at ' num2str(start_cf) ' end at the duration of the trial'])
end


%% take only interested data
for idx_f = 1:length(files)
    file = fullfile(path, files(idx_f).name);
    load(file);
    info.files = cat(1, info.files, file);
    nchannels = length(channels_label);

    %% processing
%     signal = signal(:,1:nchannels);

    % Apply lap filter
%     disp('      [PROC] Apply lap filter');
    load(lap_path39)
    info.lap = lap;
%     s_lap = signal * lap;

    % Apply filtering in band
    disp(['      [PROC] Apply filter ' num2str(band(1)) '-' num2str(band(2)) 'hz']);
    [b, a] = butter(filterOrder, band*2/sampleRate);
    s_band = filtfilt(b, a, signal);
%     s_band = filtfilt(b, a, s_lap);

    % Rect the signal
    disp('      [PROC] Rectifing signal');
    s_power = power(s_band, 2);
%    s_power = abs(s_band);

    % Apply average windows
    disp('      [PROC] Apply average windows');
    avg = 1;
    windowSize = avg * sampleRate;
%     windowSize = 2048;
    s_avg = zeros(size(s_power));
    for ch=1:nchannels
        s_avg(:,ch) = filter(ones(1, windowSize)/(windowSize), 1, s_power(:,ch));
    end

    % Apply log
    disp('      [PROC] Apply log to have log band power');
    s_log = log(s_avg);


    %% take only interested values
    idx_interest_ch = zeros(1, numel(selchs));
    for i=1:numel(selchs)
        idx_interest_ch(i) = find(strcmp(channels_label, selchs{i}));
    end

    cueStart = header.EVENT.POS(ismember(header.EVENT.TYP, classes));
    cfStart = header.EVENT.POS(header.EVENT.TYP==781);
    cfDur = header.EVENT.DUR(header.EVENT.TYP==781);
    cfTyp = header.EVENT.TYP(ismember(header.EVENT.TYP, classes));
    % for each trial take only the part of cf we are interest in
    for idx_cf = 1:length(cfStart)

        c_cfStart = cfStart(idx_cf) + floor(start_cf*sampleRate);
%         c_cfStart = cueStart(idx_cf);
%         info.cfStart = cat(1, info.cfStart, size(X,1) + c_cfStart);

        if end_cf ~= 0
            c_cfEnd = cfStart(idx_cf) + floor(end_cf*sampleRate);
        else
            c_cfEnd = cfStart(idx_cf) + cfDur(idx_cf);
        end


        % take only the interested channels and the correspondig frequencies
        tmp_s = s_log(c_cfStart:c_cfEnd-1,idx_interest_ch);
        info.cfStart = cat(1, info.cfStart, size(X,1));
        info.cfDur = cat(1, info.cfDur, size(tmp_s,1));
        X = cat(1, X, tmp_s);
        y = cat(1, y, repmat(cfTyp(idx_cf), size(tmp_s,1), 1));
    end

    
    info.startNewFile = cat(1, info.startNewFile, length(X));
end

info.startTest = info.cfStart(floor(train_percentage * size(info.cfStart,1)));

%% save the values
save(sfile, 'X', 'y', 'info');
