function s_moveavg = processing_offline(signal, lap_path, nchannels, sampleRate, band, filtOrder, avg)
disp('[INFO] start processing');

s_car = signal - mean(signal, 2);
% laplacian filter
disp('   [proc] applying laplacian')
load(lap_path);
s_lap = signal * lap;


% filter alpha band
disp('   [proc] applying filtering')
[b_alpha, a_alpha] = butter(filtOrder, band*2/sampleRate);
s_filt = zeros(size(signal));
for idx_ch = 1:nchannels
    s_filt(:,idx_ch) = filtfilt(b_alpha, a_alpha, signal(:,idx_ch));
end

% squaring
disp('   [proc] applying power')
s_rect = power(s_filt, 2);

% average windows 1 sec
disp('   [proc] applying average window')
s_moveavg = zeros(size(signal));
for idx_ch=1:nchannels
    s_moveavg(:, idx_ch) = (filter(ones(1,avg*sampleRate)/avg/sampleRate, 1, s_rect(:, idx_ch)));
end

end