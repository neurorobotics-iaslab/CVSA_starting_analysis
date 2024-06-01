clc; clear all; close all;
% create the dataset according to freq selected, channels, day
% in this dataset there is a subtraction of cf - fix in the psd values

%% informations
% selFreqs = {8:2:14; 8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14;8:2:14};
% selchs = {'P3', 'PZ', 'P4', 'POZ', 'O1', 'O2', 'P5', 'P1', 'P2', 'P6', 'PO5', 'PO3', 'PO4', 'PO6', 'PO7', 'PO8', 'OZ'};
% selFreqs = {[10 14]; [10]; [10 14]}; % luca features
% selchs = {'OZ', 'PO8', 'O1'};
% selFreqs = {[10 12]; [12]; [10]}; % paolo features
% selchs = {'PO4', 'O2', 'PO7'}; % paolo features
selFreqs = {[10 12]; [14]; [10]}; % paolo features new data
selchs = {'PO5', 'PO8', 'PO4'}; % paolo features new data
c_day = '20240515';
c_subject = 'c7';
start_cf = 0; % from which second you extract data, with 0 take the start of the trial
end_cf = 0; % end of the trial extracted, with 0 take all the trial length
train_percentage = 0.75;


%
classes = [730 731];
sampleRate = 512;
lap_path39 = '/home/paolo/laplacians/lap_39ch_CVSA.mat';
sfile = ['/home/paolo/cvsa_ws/record/dataset/' c_subject c_day 'b.mat'];

path = ['/home/paolo/cvsa_ws/record/' c_subject '/mat_selectedTrials'];
files = dir(fullfile(path, ['*' c_day '*.mat']));

channels_label = {'FP1', 'FP2', 'F3', 'FZ', 'F4', 'FC1', 'FC2', 'C3', 'CZ', 'C4', 'CP1', 'CP2', 'P3', 'PZ', 'P4', 'POZ', 'O1', 'O2', 'EOG', ...
        'F1', 'F2', 'FC3', 'FCZ', 'FC4', 'C1', 'C2', 'CP3', 'CP4', 'P5', 'P1', 'P2', 'P6', 'PO5', 'PO3', 'PO4', 'PO6', 'PO7', 'PO8', 'OZ'};

%% initialization variable to save
X = [];
y = [];

info.classes = classes;
info.sampleRate = sampleRate;
info.selFreqs = selFreqs;
info.selchs = selchs;
info.startTimeCfExtracted = start_cf;
info.files = {};
info.cfStart = [];
info.cfDur = [];
info.startNewFile = [0];

%% check the end and start of extraction
if end_cf < start_cf
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

    %% processing
    load(lap_path39)
    info.lap = lap;
    signal = signal(:,1:length(channels_label));
    signal = signal * lap;
    psd_wlength = 0.5;
    psd_wshift = 0.0625;
    psd_pshift = 0.25;
    psd_mlength =  1;
    info.psd.wlength = psd_wlength;
    info.psd.wshift = psd_wshift;
    info.psd.pshift = psd_pshift;
    info.psd.mlength = psd_mlength;
    [features, f] = proc_spectrogram(signal, psd_wlength, psd_wshift, psd_pshift, sampleRate, psd_mlength);
    features = log(features);
    header.EVENT.POS = proc_pos2win(header.EVENT.POS, psd_wshift*sampleRate, 'backward', psd_mlength*sampleRate);
    header.EVENT.DUR = floor(header.EVENT.DUR/(psd_wshift*sampleRate)) + 1;
    header.EVENT.TYP = header.EVENT.TYP;

    %% take only interested values
    idx_interest_ch = zeros(1, numel(selchs));
    for i=1:numel(selchs)
        idx_interest_ch(i) = find(strcmp(channels_label, selchs{i}));
    end

    fixStart = header.EVENT.POS(header.EVENT.TYP == 786);
    fixDur = header.EVENT.DUR(header.EVENT.TYP == 786);

    cfStart = header.EVENT.POS(header.EVENT.TYP==781);
    cfDur = header.EVENT.DUR(header.EVENT.TYP==781);
    cfTyp = header.EVENT.TYP(ismember(header.EVENT.TYP, classes));
    % for each trial take only the part of cf we are interest in
    for idx_cf = 1:length(cfStart)

        c_cfStart = cfStart(idx_cf) + floor(start_cf/psd_wshift);

        if end_cf ~= 0
            c_cfEnd = cfStart(idx_cf) + floor(end_cf/psd_wshift);
        else
            c_cfEnd = cfStart(idx_cf) + cfDur(idx_cf);
        end

        % take only the interested channels and the correspondig frequencies of the fix
        tmp_s_fix = [];
        c_fixStart = fixStart(idx_cf);
        c_fixEnd = c_fixStart + fixDur(idx_cf);
        for idx_ch=1:length(idx_interest_ch)
            c_f = selFreqs{idx_ch};
            idx_selFreqs = find(ismember(f,c_f));
            t_s = features(c_fixStart:c_fixEnd -1, idx_selFreqs, idx_interest_ch(idx_ch));
            tmp_s_fix = cat(2, tmp_s_fix, t_s);
        end
        mean_fix = mean(tmp_s_fix, 1);

        % take only the interested channels and the correspondig frequencies of the cf
        tmp_s_cf = [];
        for idx_ch=1:length(idx_interest_ch)
            c_f = selFreqs{idx_ch};
            idx_selFreqs = find(ismember(f,c_f));
            t_s = features(c_cfStart:c_cfEnd -1, idx_selFreqs, idx_interest_ch(idx_ch));
            tmp_s_cf = cat(2, tmp_s_cf, t_s);
        end
        tmp_s_cf = tmp_s_cf - repmat(mean_fix, size(tmp_s_cf, 1),1);
        info.cfStart = cat(1, info.cfStart, size(X,1));
        info.cfDur = cat(1, info.cfDur, size(tmp_s_cf,1));
        X = cat(1, X, tmp_s_cf);
        y = cat(1, y, repmat(cfTyp(idx_cf), size(tmp_s_cf,1), 1));
    end

    info.startNewFile = cat(1, info.startNewFile, length(X));
end

info.startTest = info.cfStart(floor(train_percentage * size(info.cfStart,1)));

%% save the values
save(sfile, 'X', 'y', 'info');