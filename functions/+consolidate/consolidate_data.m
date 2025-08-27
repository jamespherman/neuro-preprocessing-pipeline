function success = consolidate_data(job, config)
    % consolidate_data: Main function for the consolidation stage.
    %
    % This function takes a job and the pipeline config, loads the
    % intermediate data and Kilosort output, merges them, and saves
    % the final, analysis-ready session_data.mat file.
    %
    % Args:
    %   job (table row): The current job's data from the manifest.
    %   config (struct): The pipeline's configuration parameters.
    %
    % Returns:
    %   success (logical): True if consolidation is successful, false otherwise.

    fprintf('Consolidating data for %s...\n', job.unique_id);

    % TODO: Implement the actual consolidation logic here.
    % For now, we'll just simulate success.
    success = true;

    fprintf('Consolidation complete for %s.\n', job.unique_id);
end
