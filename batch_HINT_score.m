function output = batch_HINT_score(subject_id, test_id)

% % DESCRIPTION:
%
%   Batch Analysis script for HINT: trial to trial scoring


%% GET INPUT PARAMETERS

% subject_id
%   - four-digit number. enter as numerical
% 
% test_id
%   - Must be entered exactly as {'HINT (SNR-50, ISTS)' 'HINT (SNR-50, SPSHN)' 'HINT (SNR-80, ISTS)' 'HINT (SNR-80, SPSHN)'}
%   - Current version of the code does not work for fewer tests input or in
%       a different order. Future version will have more flexibility. 
% 
% plot
%   -0=no plotting, 1=plotting
% 
% Create dummy cell
trial_info_data{1}=0;
 ouput_data{1}=0;
 ouput_trial{1}=0;
%% BEGIN LOOP. EACH CYCLE REPRESENTS A SUBJECT

for i=1:length(subject_id)
    sub_id=subject_id(i);
    %% BEGIN LOOP. EACH CYCLE REPRESENTS A TEST_ID
    for j=1:length(test_id)
        %% IDENTIFY TEST RESULT FILENAME
        test_id;
        test=test_id(j);
            
        ftest_id= strcat('*',test,'*');
        num2str(subject_id(i)),char(ftest_id);
        fullfile(num2str(subject_id(i)),char(ftest_id));
        filename=dir(fullfile(num2str(subject_id(i)),char(ftest_id)))
      
        if length(filename)>1
            filename=filename(1)
        end
        length(filename)
        
        if length(filename)==0
         % rtsdata=[subject_id(i) NaN NaN];   
%          time_series={NaN}

        else
            
        %% LOAD DATA
        TestResults=load(filename.name);
        
        %% EXTRACT Trial to trial scoring data
%          Modify test name for output purpose
            if strcmp(test,'HINT (SNR-50, ISTS)')==1
                test='HINT_SNR-50_ISTS';
            end
            if strcmp(test,'HINT (SNR-50, SPSHN)')==1
                test='HINT_SNR-50_SPSHN';
            end
            if strcmp(test,'HINT (SNR-80, ISTS)')==1
                test='HINT_SNR-80_ISTS';
            end
            if strcmp(test,'HINT (SNR-80, SPSHN)')==1
                test='HINT_SNR-80_SPSHN';
            end 
        
        tttdata=TestResults.results(1).RunTime.player.modcheck.trial_info;
        trial_num=length(tttdata);
        sub_id_out={sub_id};
        test_id_out={test};
%         test_id_array=repmat(test,trial_num,1)
%         test_id_cell=cellstr(test_id_array)
%         ttt_dataset= [sub_id_cell test_id_cell]

            for k=1:trial_num
                id=tttdata{k}.id;
                filepath=tttdata{k}.filepath;
                sentence=tttdata{k}.sentence;
                scoringunits=tttdata{k}.scoringunits;
                score=tttdata{k}.score;
                trial_info=[sub_id_out test_id_out id filepath sentence scoringunits score];
                
                if trial_info_data{1}==0
                    trial_info_data=[trial_info];
                else
                    trial_info_data=[trial_info_data;trial_info];
                end
            end
            
         
%      
        end
    end
        if ouput_trial{1}==0
        output_trial=[trial_info_data];
        else
        output_trial=[output_trial trial_info_data];
        end
%     if ouput_data{1}==0
%         output_data=[output_trial]
%     else
%         output_data=[output_data output_trial]
%     end
end
  
%% 
output_data=cell2table(output_trial)

output_data.Properties.VariableNames{'output_trial1'}='SubID';
output_data.Properties.VariableNames{'output_trial2'}='TestID';
output_data.Properties.VariableNames{'output_trial3'}='ID';
output_data.Properties.VariableNames{'output_trial4'}='filepath';
output_data.Properties.VariableNames{'output_trial5'}='sentence';
output_data.Properties.VariableNames{'output_trial6'}='scoring_units';
output_data.Properties.VariableNames{'output_trial7'}='score';

writetable(output_data,'batch_HINT_score.csv');


