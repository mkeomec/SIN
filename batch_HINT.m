function output = batch_HINT(subject_id, test_id,plot,calculate_srt)

% % DESCRIPTION:
%
%   Group Analysis script for HINT


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
% calculate_srt
%   NOTE: as of 10/4/2015, only HINT-80 files contain the data neccessary
%   to run reversal mean. This batch analysis will not work for HINT-50
%   files trying to run reversal means
% 
%   -0=trial mean
%   -1=reversal mean
%   -2=default

% % % d=varargin2struct(varargin{:});
% %% IS THIS AN OPTIONS STRUCTURE
% %   If not, then force it to look like one.
% if ~isfield(d, 'subject')
%     d = SIN_TestSetup('Defaults', d.subjectID); 
% end % isstruct
% 
% % Set defaults
% if ~isfield(d, 'regexp'), d.regexp = '.mat'; end
% 
% %% GET TEST INFORMATION
% all_tests = regexpdir(d.subject.subjectDir, d.regexp, false);

 start_at_reversal=0;
%% BEGIN LOOP. EACH CYCLE REPRESENTS A SUBJECT

for i=1:length(subject_id)
    
    %% BEGIN LOOP. EACH CYCLE REPRESENTS A TEST_ID
    for j=1:length(test_id)
        %% IDENTIFY TEST RESULT FILENAME
        test=test_id(j);
            
        ftest_id= strcat('*',test,'*');
        num2str(subject_id(i)),char(ftest_id)
        fullfile(num2str(subject_id(i)),char(ftest_id))
        filename=dir(fullfile(num2str(subject_id(i)),char(ftest_id)))
        
        if length(filename)>0
            filename=filename(1)
        end        
    
         if length(filename)==0
         rtsdata=[subject_id(i) NaN NaN];   
         time_series={NaN}

        else
        % %% CREATE FILENAMES BASED ON subject_id AND test_id
        % 
        % sub_id=num2str(subject_id(i))
        % prefilename= strcat(sub_id,'-',test_id,'*')
        % prefilename=dir(prefilename)
        % filename=prefilename.name

        %% LOAD DATA
        TestResults=load(filename.name);
        
        

        %% Turn off plotting to reduce computation time
        TestResults.results(1).RunTime.analysis.params.plot=plot;
        
        %% Set RTS analysis type 
        if calculate_srt=='0'
            TestResults.results(1).RunTime.analysis.params.RTSest='trial_mean';
        end
        if calculate_srt=='1'
            TestResults.results(1).RunTime.analysis.params.RTSest='reversal_mean';
         
% For SNR 50 when running forced reversal mean calculation, force start_at_reversal value to 1
            if isfield (TestResults.results(1).RunTime.analysis.params,'start_at_reversal')==0
                TestResults.results(1).RunTime.analysis.params.start_at_reversal=1;
            end
          
        end
        
        
        
        %% RUN ANALYSIS 

        [rts, rts_std time_series]=analysis_HINT_test(TestResults,TestResults.results(1).RunTime.analysis.params);
        time_series=mat2str(time_series);
        time_series=cellstr(time_series);
        
        %% EXTRACT RTS
        
        rtsdata=[subject_id(i) rts rts_std];
        end
%         Outputdata(2i-1:2i,1)=subject_id(i)
%         Outputdata(j) =
        Subj_outputdata(1,1)=rtsdata(1);
        Subj_outputdata(1,2*j)=rtsdata(2);
        Subj_outputdata(1,(2*j)+1)=rtsdata(3);
        test_id_header(:,j)=test_id(j);

%       Modify test name for output purpose
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
        test=cellstr(test);
        outid((4*i)-3:4*i,:)=subject_id(i);
        ((4*i)-4+j);
        outtest(((4*i)-4+j),:)=test;
        outdata((4*i)-4+j,:)=time_series;
        
        
%       Report the start_at_reversal value. For trial_mean (SNR50), this
%       value is forced to 1, so it is reported as 0.
      
        if isequal('reversal_mean',TestResults.results(1).RunTime.analysis.params.RTSest)==1            
        start_at_reversal(length(start_at_reversal)+1,:)=TestResults.results(1).RunTime.analysis.params.start_at_reversal;
        end

    end
    tempdata(i,:)=Subj_outputdata;
    outputdata((2*i)-1:(2*i),1)=tempdata(i,1);
    outputdata((2*i)-1,2:3)=tempdata(i,2:3);
    outputdata((2*i)-1,4:5)=tempdata(i,6:7);
    outputdata(2*i,2:3)=tempdata(i,4:5);
    outputdata(2*i,4:5)=tempdata(i,8:9);
    outputdata((2*i)-1,6)=30/(outputdata((2*i)-1,4)-(outputdata((2*i)-1,2)));
    outputdata((2*i),6)=30/(outputdata((2*i),4)-(outputdata((2*i),2)));
    outputdata((2*i)-1,7)=(outputdata((2*i)-1,6)/(outputdata(((2*i)-1),4)-outputdata(((2*i)-1),2)));
    outputdata((2*i),7)=(outputdata((2*i),6)/(outputdata(2*i,4)-outputdata(2*i,2)));
end
end
        
%% 

% %% CREATE CVS FILE

% % Create labels for file output

% noise=['ISTS ';'SPSHN'];
% noise=repmat(noise,[size(outputdata/2),1])
% noise=cellstr(noise);
% 
% SRT=TestResults.results(1).RunTime.analysis.params.RTSest
% SRT=repmat(noise,[size(outputdata),1])
% SRT=cellstr(SRT)

% % Create tables of all SRT output variables
outputdata=array2table(outputdata);

noise=['ISTS ';'SPSHN'];
noise=repmat(noise,[height(outputdata)/2,1]);
noise=cellstr(noise);

if calculate_srt=='2'
     TestResults.results(1).RunTime.analysis.params.RTSest='default';
end
SRT=TestResults.results(1).RunTime.analysis.params.RTSest;
SRT=repmat(SRT,[height(outputdata),1]);
SRT=cellstr(SRT);



noise=table(noise);
SRT=table(SRT);
outputtable=[outputdata noise SRT];

outputtable.Properties.VariableNames{'outputdata1'}='SubID';
outputtable.Properties.VariableNames{'outputdata2'}='mean_SNR50';
outputtable.Properties.VariableNames{'outputdata3'}='sd_SNR50';
outputtable.Properties.VariableNames{'outputdata4'}='mean_SNR80';
outputtable.Properties.VariableNames{'outputdata5'}='sd_SNR80';
outputtable.Properties.VariableNames{'outputdata6'}='slope';
outputtable.Properties.VariableNames{'outputdata7'}='slope_dB';
outputtable.Properties.VariableNames{'noise'}='noise_type';
outputtable.Properties.VariableNames{'SRT'}='SRT_calculation_Setting';
writetable(outputtable,'batch_HINT.csv');

% Create table to output all time_series variables


outid=table(outid);
outtest=table(outtest);
outdata=table(outdata);

time_series_data=[outid outtest outdata];
time_series_data.Properties.VariableNames{'outid'}='SubID';
time_series_data.Properties.VariableNames{'outtest'}='Test_ID';
time_series_data.Properties.VariableNames{'outdata'}='Time_Series';
writetable(time_series_data,'batch_HINT_TimeSeries.csv');





% outputdata
% size_outputdata=size(outputdata)
% outid=fopen('batch_HINT.csv','w+')
% header='Subject_ID, HINT_(SNR-50_ISTS), HINT_(SNR-50_SPSHN), HINT_(SNR-80_ISTS), HINT_(SNR-80_SPSHN)'
% fprintf(outid, '%s\n', header);
% for i = 1:size_outputdata(1)
% outLine = regexprep(num2str(outputdata(i,1:5)), '  *', ',');
% fprintf(outid, '%s\n', outLine);
% end
% fclose(outid)



% headers={'Subject_ID RTS' char(test_id_header(1)) char(test_id_header(2)) char(test_id_header(3)) char(test_id_header(4))}
% csvwrite(strcat('batch',test_id,'.csv'),headers)

% headers={
% filename = 'batch_HINT.csv';
% header={'Subject_ID' 'HINT_(SNR-50,ISTS)' 'HINT_(SNR-50,SPSHN)' 'HINT_(SNR-80,ISTS)' 'HINT_(SNR-80,SPSHN)'}
% fid = fopen(filename, 'w');
% % fprintf('%s %s %s %s\n', 'col1', 'col2', 'col3', 'col4');
% % fprintf(fid, '%s %s %s %s %s\n','Subject_ID', 'HINT_(SNR-50,ISTS)','HINT_(SNR-50,SPSHN)', 'HINT_(SNR-80,ISTS)','HINT_(SNR-80,SPSHN)' );
% fpintf(fid, '%s,', header{1,end});
% fclose(fid)

% dlmwrite(filename, outputdata, '-append', 'precision', '%.6f', 'delimiter', '\t');

% %% MULTI-STAGE TEST
% %   Most implementations of HINT are seen as two-stage tests. We want the
% %   scoring to be based of the last segment (typically)
% runtime = results(end).RunTime;

