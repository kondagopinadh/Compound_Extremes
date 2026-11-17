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
hw_dir = '/Volumes/Atm_River/Extremes/Tmax/';
pr_dir = '/Volumes/Atm_River/Extremes/PRCP/Extrm_data/';
out_dir = '/Users/gopinadh/Downloads/';

for m = 1:length(models)
    model = models{m};

    for s = 1:length(scenarios)
        scenario = scenarios{s};
        fprintf('🔄 Processing: %s | %s\n', model, scenario);

        try
            % Locate input files
           hw_file = dir(fullfile(hw_dir, ['HWD_tmax_' model '_' scenario '*.mat']));
            pr_file = dir(fullfile(pr_dir, ['pr_extrm_' model '_' scenario '*.mat']));

            if isempty(hw_file) || isempty(pr_file)
                fprintf('⚠️ Missing files for %s %s\n', model, scenario);
                continue;
            end

            % Load data
            load(fullfile(hw_dir, hw_file(1).name));   % loads hwd_tmp, lon, lat, time
            load(fullfile(pr_dir, pr_file(1).name));   % loads pr95_out
            pr95_out(pr95_out < 1) = NaN;

            % Dimension check
            if ~isequal(size(hwd_tmp), size(pr95_out))
                warning('⚠️ Size mismatch for %s %s. Skipping.', model, scenario);
                continue;
            end

            [nlon, nlat, nt] = size(hwd_tmp);
            tasmax_event = NaN(nlon, nlat, nt);  % Output array
            pr_event = NaN(nlon, nlat, nt);

            % Find grid points with valid data
            valid_mask = ~all(isnan(hwd_tmp), 3) & ~all(isnan(pr95_out), 3);
            [I, J] = find(valid_mask);

            % Main loop per grid point
            for idx = 1:length(I)
                i = I(idx);
                j = J(idx);
            
                Tmax_series = squeeze(hwd_tmp(i,j,:));
                Pr_series   = squeeze(pr95_out(i,j,:));
            
                coincident = ~isnan(Tmax_series) & ~isnan(Pr_series);
            
                tasmax_event(i,j,coincident) = Tmax_series(coincident);
                pr_event(i,j,coincident)     = Pr_series(coincident);
                % idx
            end

            % Save output
            output_name = sprintf('heat_Extrem_coincident_event_%s_%s.mat', model, scenario);
            output_path = fullfile(out_dir, output_name);
            save(output_path, 'lon', 'lat', 'time', 'pr_event', 'tasmax_event', '-v7.3');
            fprintf('✅ Saved: %s\n\n', output_name);

            % Clear memory
            clear hwd_tmp pr95_out tasmax_event pr_event lon lat time I J;

        catch ME
            fprintf('❌ Error in %s %s: %s\n', model, scenario, ME.message);
            continue;
        end
    end
end


