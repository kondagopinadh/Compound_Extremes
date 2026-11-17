clc;
clear;
close all;

% === Model and Scenario Lists ===
models = {'ACCESS-CM2', 'ACCESS-ESM1-5', 'BCC-CSM2-MR', 'CanESM5',...
    'CMCC-CM2-SR5', 'CMCC-ESM2', 'EC-Earth3-Veg-LR', 'EC-Earth3',...
    'GFDL-CM4', 'GFDL-ESM4', 'INM-CM4-8', 'INM-CM5-0',...
    'IPSL-CM6A-LR','KIOST-ESM', 'MIROC6', 'MPI-ESM1-2-HR', ...
    'MPI-ESM1-2-LR', 'MRI-ESM2-0', 'NESM3', ...
    'NorESM2-LM', 'NorESM2-MM', 'TaiESM1'}';

scenarios = {'historical', 'ssp126', 'ssp245', 'ssp370', 'ssp585'};

% Directories
tmp_dir = '/proj/gopinadh/NASA-NexGDDP/tasmax/HWD_files/';
pr_dir  = '/proj/gopinadh/NASA-NexGDDP/pr/extremes/';
out_dir = '/proj/gopinadh/NASA-NexGDDP/pr/extremes/';

for m = 1%:length(models)
    model = models{m};

    for s = 1:length(scenarios)
        scenario = scenarios{s};
        fprintf('🔄 Processing: %s | %s\n', model, scenario);

        % === Find Files ===
        hw_file = dir(fullfile(hw_dir, ['HWD_tmax_' model '_' scenario '*.mat']));
        pr_file = dir(fullfile(pr_dir, ['pr_extrm_' model '_' scenario '*.mat']));

        if isempty(hw_file) || isempty(pr_file)
            fprintf('⚠️ Missing files for %s %s\n', model, scenario);
            continue;
        end

        % === Load Data ===
        load(fullfile(hw_dir, hw_file(1).name));   % loads hwd_tmp, lon, lat, time
        load(fullfile(pr_dir, pr_file(1).name));   % loads pr95_out

        % Mask very small rain values
        pr95_out(pr95_out < 1) = NaN;

        if ~isequal(size(hwd_tmp), size(pr95_out))
            warning('⚠️ Size mismatch for %s %s. Skipping.\n', model, scenario);
            continue;
        end

        [nlon, nlat, nt] = size(hwd_tmp);

        % === Initialize Outputs ===
        hwd1      = NaN(nlon, nlat, nt);
        hwd2      = NaN(nlon, nlat, nt);
        pr_event  = NaN(nlon, nlat, nt);

        % === Process grid points ===
        valid_mask = ~all(isnan(hwd_tmp), 3) & ~all(isnan(pr95_out), 3);
        [I, J] = find(valid_mask);

        for idx = 1:length(I)
            i = I(idx);
            j = J(idx);
            idx

            hwd_series   = squeeze(hwd_tmp(i, j, :));
            extpr_series = squeeze(pr95_out(i, j, :));

            hwd_logical   = ~isnan(hwd_series);
            extpr_logical = ~isnan(extpr_series);

            if all(~hwd_logical) || all(~extpr_logical)
                continue;
            end

            % Masks for hwd1, hwd2, and rain events
            hwd1_mask = false(nt, 1);
            hwd2_mask = false(nt, 1);
            pr_between_mask = false(nt, 1);

            % Identify heatwave streaks
            hwd_streaks = regionprops(hwd_logical, 'PixelIdxList');

            if length(hwd_streaks) >= 2
                for r = 1:(length(hwd_streaks)-1)
                    hw1_days = hwd_streaks(r).PixelIdxList;
                    hw2_days = hwd_streaks(r+1).PixelIdxList;

                    hw1_end   = max(hw1_days);
                    hw2_start = min(hw2_days);
                    gap_days = hw2_start - hw1_end - 1;

                    if gap_days >= 0 && gap_days <= 7
                        rain_gap_idx = hw1_end+1 : hw2_start-1;
                        rain_between = extpr_logical(rain_gap_idx);

                        if any(rain_between)
                            hwd1_mask(hw1_days) = true;
                            hwd2_mask(hw2_days) = true;
                            pr_between_mask(rain_gap_idx) = rain_between;
                        end
                    end
                end
            end

            % Filter series
            hwd1_series = hwd_series; hwd1_series(~hwd1_mask) = NaN;
            hwd2_series = hwd_series; hwd2_series(~hwd2_mask) = NaN;
            pr_series   = extpr_series; pr_series(~pr_between_mask) = NaN;

            % Remove heatwaves if no rain event is present
            if all(isnan(pr_series))
                hwd1_series(:) = NaN;
                hwd2_series(:) = NaN;
            end

            % Store results
            hwd1(i,j,:) = hwd1_series;
            hwd2(i,j,:) = hwd2_series;
            pr_event(i,j,:) = pr_series;
        end

        % === Save Output ===
        output_name = sprintf('HW_PR_HW_event_%s_%s.mat', model, scenario);
        output_path = fullfile(out_dir, output_name);
        save(output_path, 'lon', 'lat', 'time', 'hwd1', 'pr_event', 'hwd2', '-v7.3');
        fprintf('✅ Saved: %s\n\n', output_name);
    end
end

fprintf('🎉 All models and scenarios processed.\n');
