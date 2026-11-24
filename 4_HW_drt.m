clc; clear; close all;

% List of models and scenarios
models = {'ACCESS-CM2', 'ACCESS-ESM1-5', 'BCC-CSM2-MR', 'CanESM5', ...
    'CMCC-CM2-SR5', 'CMCC-ESM2', 'EC-Earth3', 'EC-Earth3-Veg-LR', ...
    'GFDL-CM4', 'IITM-ESM', 'INM-CM4-8', 'INM-CM5-0', ...
    'IPSL-CM6A-LR', 'KACE-1-0-G', 'KIOST-ESM', 'MIROC6', ...
    'MPI-ESM1-2-HR', 'MPI-ESM1-2-LR', 'MRI-ESM2-0', 'NESM3', ...
    'NorESM2-LM', 'NorESM2-MM', 'TaiESM1'}';

scenarios = {'historical', 'ssp126', 'ssp245', 'ssp370', 'ssp585'};

% Directories
hw_dir = '/Volumes/Atm_River/Extremes/Tmax/';
pr_dir = '/Volumes/Atm_River/Extremes/PRCP/drought/';
out_dir = '/Users/gopinadh/Downloads/';

for m = 1:length(models)
    model = models{m};

    for s = 1:length(scenarios)
        scenario = scenarios{s};
        fprintf('🔄 Processing: %s | %s\n', model, scenario);

        % Locate input files
        hw_file = dir(fullfile(hw_dir, ['HWD_tmax_' model '_' scenario '*.mat']));
        pr_file = dir(fullfile(pr_dir, ['Drt_5days_' model '_' scenario '*.mat']));

        if isempty(hw_file) || isempty(pr_file)
            fprintf('⚠️ Missing files for %s %s\n', model, scenario);
            continue;
        end

        % Load data
        load(fullfile(hw_dir, hw_file(1).name));  % hwd_tmp, lon, lat, time
        load(fullfile(pr_dir, pr_file(1).name));  % drt_pr

        if ~isequal(size(hwd_tmp), size(drt_pr))
            warning('⚠️ Size mismatch in %s %s. Skipping.', model, scenario);
            continue;
        end

        [nlon, nlat, nt] = size(hwd_tmp);

        % Initialize result arrays
        tasmax_event = NaN(nlon, nlat, nt);
        pr_event     = NaN(nlon, nlat, nt);

        % Find valid grid points where both variables have data
        valid_mask = ~all(isnan(hwd_tmp),3) & ~all(isnan(drt_pr),3);
        [I, J] = find(valid_mask);

        for idx = 1:length(I)
            i = I(idx); j = J(idx);

            Tmax_series = squeeze(hwd_tmp(i,j,:));
            Pr_series   = squeeze(drt_pr(i,j,:));

            % Identify heatwave streaks using bwlabel
            [labels_hw, n_hw] = bwlabel(~isnan(Tmax_series));

            if n_hw == 0
                continue;
            end

            for h = 1:n_hw
                hw_days = find(labels_hw == h);
                hw_end  = max(hw_days);

                if hw_end >= nt
                    continue;
                end

                % Look ahead up to 7 days after the heatwave
                search_end = min(hw_end+7, nt);
                pr_window = ~isnan(Pr_series(hw_end+1:search_end));

                % Identify drought streaks
                [labels_drt, n_drt] = bwlabel(pr_window);

                for d = 1:n_drt
                    drt_days = find(labels_drt == d);
                    if length(drt_days) >= 5
                        % Map drought days back to time index
                        drt_days = drt_days + hw_end;
                        tasmax_event(i,j,hw_days) = Tmax_series(hw_days);
                        pr_event(i,j,drt_days)    = Pr_series(drt_days);
                        break;  % stop after first qualifying drought streak
                    end
                end
            end
        end

        % Save results
        tasmax = tasmax_event;
        pr     = pr_event;

        output_name = sprintf('heat_dry_7_days_event_%s_%s_allDays.mat', model, scenario);
        output_path = fullfile(out_dir, output_name);
        save(output_path, 'lon', 'lat', 'time', 'tasmax', 'pr', '-v7.3');
        fprintf('✅ Saved: %s\n\n', output_name);
    end
end

fprintf('🎉 All models and scenarios processed.\n');
