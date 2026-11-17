
clc;
clear;
close all;

% List of models and scenarios
models = {'ACCESS-CM2', 'ACCESS-ESM1-5', 'BCC-CSM2-MR', 'CanESM5',...
    'CMCC-CM2-SR5', 'CMCC-ESM2', 'EC-Earth3-Veg-LR', 'EC-Earth3',...
    'GFDL-CM4', 'GFDL-ESM4', 'INM-CM4-8', 'INM-CM5-0',...
    'IPSL-CM6A-LR','KIOST-ESM', 'MIROC6', 'MPI-ESM1-2-HR', 'MPI-ESM1-2-LR', 'MRI-ESM2-0',...
    'NESM3', 'NorESM2-LM', 'NorESM2-MM', 'TaiESM1'}';

scenarios = {'historical', 'ssp126', 'ssp245', 'ssp370', 'ssp585'};

% Directories
tmp_dir = '/Volumes/Atm_River/Extremes/Tmax/';
pr_dir = '/Volumes/Atm_River/Extremes/PRCP/drought/';
out_dir = '/Volumes/Atm_River/Extremes/PRCP/drought/';

for m = 1:length(models)
    model = models{m};

    for s = 1:length(scenarios)
        scenario = scenarios{s};
        fprintf('🔄 Processing: %s | %s\n', model, scenario);

        % Locate input files
        files = dir(fullfile(tmp_dir, ['HWD_tmax_' model '_' scenario '*.mat']));
        files1 = dir(fullfile(pr_dir, ['Drt_5days_' model '_' scenario '*.mat']));

        if isempty(files) || isempty(files1)
            fprintf('⚠️ Missing files for %s %s\n', model, scenario);
            continue;
        end

        % Load data
        load(fullfile(tmp_dir, files(1).name));  % hwd_tmp, lon, lat, time
        load(fullfile(pr_dir, files1(1).name));  % drt_pr
          

        if ~isequal(size(hwd_tmp), size(drt_pr))
            warning('⚠️ Size mismatch in %s %s. Skipping.', model, scenario);
            continue;
        end

        [nlon, nlat, nt] = size(hwd_tmp);
        tasmax_event = NaN(nlon, nlat, nt);
        pr_event = NaN(nlon, nlat, nt);

        % Precompute valid grid indices
        valid_mask = ~all(isnan(hwd_tmp), 3) & ~all(isnan(drt_pr), 3);
        [I, J] = find(valid_mask);
        num_points = length(I);

        % Use parfor loop
        for idx = 1:num_points
            i = I(idx);
            j = J(idx);

            Tmax_series = squeeze(hwd_tmp(i,j,:));
            Pr_series = squeeze(drt_pr(i,j,:));

            combined_logical = ~isnan(Tmax_series) & ~isnan(Pr_series);
            regions = regionprops(combined_logical, 'PixelIdxList', 'Area');
            % regions = regions([regions.Area] >= 3);

            if isempty(regions)
                continue;
            end

            valid_indices = sort(vertcat(regions.PixelIdxList));

            % Store output in local temporary variables (thread-safe)
            tmp_tas = NaN(nt, 1);
            tmp_pr = NaN(nt, 1);

            tmp_tas(valid_indices) = Tmax_series(valid_indices);
            tmp_pr(valid_indices) = Pr_series(valid_indices);

            tasmax_event(i,j,:) = tmp_tas;
            pr_event(i,j,:) = tmp_pr;
            % idx
        end

        % Save result
        output_name = sprintf('heat_dry_Coincident_event_%s_%s.mat', model, scenario);
        output_path = fullfile(out_dir, output_name);
        save(output_path, 'lon', 'lat', 'time', 'tasmax_event', 'pr_event', '-v7.3');
        fprintf('✅ Saved: %s\n\n', output_name);
    end
end
