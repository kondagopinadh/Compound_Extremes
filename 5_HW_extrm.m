clc;
clear;
close all;

% === Model and Scenario Lists ===
models = {'ACCESS-CM2', 'ACCESS-ESM1-5', 'BCC-CSM2-MR', 'CanESM5',...
    'CMCC-CM2-SR5', 'CMCC-ESM2', 'EC-Earth3-Veg-LR', 'EC-Earth3',...
    'GFDL-CM4', 'GFDL-ESM4', 'INM-CM4-8', 'INM-CM5-0',...
    'IPSL-CM6A-LR','KIOST-ESM', 'MIROC6', 'MPI-ESM1-2-HR', 'MPI-ESM1-2-LR', 'MRI-ESM2-0',...
    'NESM3', 'NorESM2-LM', 'NorESM2-MM', 'TaiESM1'}';

scenarios = {'historical', 'ssp126', 'ssp245', 'ssp370', 'ssp585'};

% Directories
hw_dir  = '/Volumes/Atm_River/Extremes/Tmax/';
pr_dir  = '/Volumes/Atm_River/Extremes/PRCP/Extrm_data/';
out_dir = '/Users/gopinadh/Downloads/';

for m = 1:length(models)
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

        % Mask small values
        pr95_out(pr95_out < 1) = NaN;

        if ~isequal(size(hwd_tmp), size(pr95_out))
            warning('⚠️ Size mismatch for %s %s. Skipping.\n', model, scenario);
            continue;
        end

        [nlon, nlat, nt] = size(hwd_tmp);

        % === Initialize Outputs ===
        pr_event  = NaN(nlon, nlat, nt);
        hwd_event = NaN(nlon, nlat, nt);

        % === Process grid points where data exists ===
        valid_mask = ~all(isnan(hwd_tmp), 3) & ~all(isnan(pr95_out), 3);
        [I, J] = find(valid_mask);

        for idx = 1:length(I)
            i = I(idx);
            j = J(idx);

            hwd_series   = squeeze(hwd_tmp(i, j, :));
            extpr_series = squeeze(pr95_out(i, j, :));

            hwd_logical   = ~isnan(hwd_series);
            extpr_logical = ~isnan(extpr_series);

            if all(~hwd_logical) || all(~extpr_logical)
                continue;
            end

            valid_hwd_event  = false(nt, 1);
            valid_rain_event = false(nt, 1);

            % Identify heatwave streaks
            hwd_streaks = regionprops(hwd_logical, 'PixelIdxList');

            for r = 1:length(hwd_streaks)
                hwd_days = hwd_streaks(r).PixelIdxList;
                hwd_end  = max(hwd_days);
                search_start = hwd_end + 1;
                if search_start > nt, continue; end

                search_end = min(hwd_end + 7, nt);
                rain_days = extpr_logical(search_start:search_end);

                if any(rain_days)
                    valid_hwd_event(hwd_days) = true;
                    actual_rain_idx = find(rain_days) + (search_start - 1);
                    valid_rain_event(actual_rain_idx) = true;
                end
            end

            % Apply logical masks via indexing
            hwd_series(~valid_hwd_event)   = NaN;
            extpr_series(~valid_rain_event) = NaN;

            hwd_event(i,j,:) = hwd_series;
            pr_event(i,j,:)  = extpr_series;
        end

        % === Save Output ===
        tasmax = hwd_event;
        pr     = pr_event;

        output_name = sprintf('heat_wet_event_%s_%s_allDays.mat', model, scenario);
        output_path = fullfile(out_dir, output_name);
        save(output_path, 'lon', 'lat', 'time', 'pr', 'tasmax', '-v7.3');
        fprintf('✅ Saved: %s\n\n', output_name);
    end
end

fprintf('🎉 All models and scenarios processed.\n');
