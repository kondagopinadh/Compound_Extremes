clc;
clear;
close all;

% List of models and scenarios
models = {'ACCESS-CM2', 'ACCESS-ESM1-5', 'BCC-CSM2-MR', 'CanESM5', ...
    'CMCC-CM2-SR5', 'CMCC-ESM2', 'EC-Earth3', 'EC-Earth3-Veg-LR', ...
    'GFDL-CM4', 'IITM-ESM', 'INM-CM4-8', 'INM-CM5-0', ...
    'IPSL-CM6A-LR', 'KACE-1-0-G', 'KIOST-ESM', 'MIROC6', ...
    'MPI-ESM1-2-HR', 'MPI-ESM1-2-LR', 'MRI-ESM2-0', 'NESM3', ...
    'NorESM2-LM', 'NorESM2-MM', 'TaiESM1'}';
    
scenarios = {'historical', 'ssp126', 'ssp245', 'ssp370', 'ssp585'};

% Directories
tmp_dir = '/Volumes/Atm_River/Extremes/PRCP/drought/';
pr_dir  = '/Volumes/Atm_River/Extremes/PRCP/Extrm_data/';
out_dir = '/Users/gopinadh/Downloads/';

for m = 1%:length(models)
    model = models{m};

    for s = 1%:length(scenarios)
        scenario = scenarios{s};
        fprintf('🔄 Processing: %s | %s\n', model, scenario);

        % Locate files
        drt_file = dir(fullfile(tmp_dir, ['Drt_5days_' model '_' scenario '*.mat']));
        pr_file  = dir(fullfile(pr_dir, ['pr_extrm_' model '_' scenario '*.mat']));

        if isempty(drt_file) || isempty(pr_file)
            fprintf('⚠️  Missing files for %s %s\n', model, scenario);
            continue;
        end

        % Load data
        load(fullfile(tmp_dir, drt_file(1).name));     % drt_pr, lon, lat, time
        load(fullfile(pr_dir, pr_file(1).name));       % pr95_out

        pr95_out(pr95_out < 1) = NaN;
        [nlon, nlat, nt] = size(drt_pr);

        if ~isequal(size(drt_pr), size(pr95_out))
            warning('⚠️  Size mismatch in %s %s. Skipping.', model, scenario);
            continue;
        end

        % Initialize output arrays
        combined_event          = NaN(nlon, nlat, nt);
        drought_only_event      = NaN(nlon, nlat, nt);
        extreme_following_event = NaN(nlon, nlat, nt);

        % Process each grid point
        parfor i = 1:nlon
            tmp_combined          = NaN(nlat, nt);
            tmp_drought_only      = NaN(nlat, nt);
            tmp_extreme_following = NaN(nlat, nt);

            for j = 1:nlat
                drought_series = squeeze(drt_pr(i,j,:));
                extreme_series = squeeze(pr95_out(i,j,:));

                if all(isnan(drought_series)) || all(isnan(extreme_series))
                    continue;
                end

                drought_logical = ~isnan(drought_series);
                extreme_logical = ~isnan(extreme_series);

                valid_event        = false(nt, 1);
                drought_event      = false(nt, 1);
                extreme_following  = false(nt, 1);

                drought_streaks = regionprops(drought_logical, 'PixelIdxList', 'Area');

                for r = 1:length(drought_streaks)
                    if drought_streaks(r).Area >= 5
                        drought_days  = drought_streaks(r).PixelIdxList;
                        drought_end   = max(drought_days);
                        search_start  = drought_end + 1;
                        if search_start > nt, continue; end
                        search_end    = min(drought_end + 7, nt);

                        if any(extreme_logical(search_start:search_end))
                            % Mark drought days
                            drought_event(drought_days) = true;
                            % Mark following extreme days
                            extreme_following(search_start:search_end) = ...
                                extreme_following(search_start:search_end) | extreme_logical(search_start:search_end);
                            % Mark combined event
                            valid_event(drought_days) = true;
                            valid_event(search_start:search_end) = ...
                                valid_event(search_start:search_end) | extreme_logical(search_start:search_end);
                        end
                    end
                end

                % Assign to temporary arrays
                % tmp_combined(j,:)          = (extreme_series .* valid_event)';
                tmp_drought_only(j,:)      = (drought_series .* drought_event)';
                % tmp_extreme_following(j,:) = (extreme_series .* extreme_following)';
            end

            % Assign to final arrays
            % combined_event(i,:,:)          = tmp_combined;
            drought_only_event(i,:,:)      = tmp_drought_only;
            % extreme_following_event(i,:,:) = tmp_extreme_following;
        end

        % Save output
        output_name = sprintf('drought_Followed_extreme_event_%s_%s_allYears.mat', model, scenario);
        output_path = fullfile(out_dir, output_name);
        save(output_path, 'lon', 'lat', 'time', ...
             'combined_event', 'drought_only_event', 'extreme_following_event', '-v7.3');

        fprintf('✅ Saved: %s\n', output_name);

    end
end

disp('✅ All models and scenarios processed.');
