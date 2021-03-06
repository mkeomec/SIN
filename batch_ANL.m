function output = batch_ANL(subject_id, test_id)

% % DESCRIPTION:
%
%   Group Analysis script for HINT

%% GET INPUT PARAMETERS

% d=varargin2struct(varargin{:});

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
%% BEGIN LOOP. EACH CYCLE REPRESENTS A SUBJECT
for i=1:length(subject_id)
    
    %% BEGIN LOOP. EACH CYCLE REPRESENTS A TEST_ID
    for j=1:length(test_id)
        %% IDENTIFY TEST RESULT FILENAME
       test=test_id(j)
        
        ftest_id= strcat('*',test,'*')
       fullfile(num2str(subject_id(i)),char(ftest_id))
        filename=dir(fullfile(num2str(subject_id(i)),char(ftest_id)))



        % %% CREATE FILENAMES BASED ON subject_id AND test_id
        % 
        % sub_id=num2str(subject_id(i))
        % prefilename= strcat(sub_id,'-',test_id,'*')
        % prefilename=dir(prefilename)
        % filename=prefilename.name

        %% LOAD DATA
        TestResults=load(filename.name)

        %% RUN ANALYSIS 

        ResultsOutput=analysis_ANL(filename.name,TestResults.results(1).RunTime.analysis.params)

        %% EXTRACT RTS
        ResultsOutput(1).RunTime.analysis.results.anl
        rtsdata=[subject_id(i) ResultsOutput(1).RunTime.analysis.results.anl]
        Subj_outputdata(i,1)=rtsdata(1)
        Subj_outputdata(i,j+1)=rtsdata(2)
        test_id_header(:,j)=test_id(j)
    end
     outputdata(i,:)=Subj_outputdata
end
        
%% 

% %% CREATE CVS FILE
headers={'Subject_ID' char(test_id_header(1)) char(test_id_header(2))}
% csvwrite(strcat('batch',test_id,'.csv'),headers)

filename = strcat('batch_ANL.csv');

fid = fopen(filename, 'w');
fprintf(fid, 'Subject_ID ANL(SessionOne) ANL(SessionTwo)\n' );
fclose(fid)

dlmwrite(filename, outputdata, '-append', 'precision', '%.6f', 'delimiter', '\t');

% %% MULTI-STAGE TEST
% %   Most implementations of HINT are seen as two-stage tests. We want the
% %   scoring to be based of the last segment (typically)
% runtime = results(end).RunTime;

