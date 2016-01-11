function output = batch_wordspan(subject_id)

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
output=0;
%% BEGIN LOOP. EACH CYCLE REPRESENTS A SUBJECT
for i=1:length(subject_id)
    
    %% BEGIN LOOP. EACH CYCLE REPRESENTS A TEST_ID
    for j=1:1
        %% IDENTIFY TEST RESULT FILENAME
       test='Word';
        
        ftest_id= strcat('*',test,'*');
        num2str(subject_id(i)),char(ftest_id);
       fullfile(num2str(subject_id(i)),char(ftest_id));
        filename=dir(fullfile(num2str(subject_id(i)),char(ftest_id)));

        if length(filename)>0
            filename=filename(1)
       

        % %% CREATE FILENAMES BASED ON subject_id AND test_id
        % 
        % sub_id=num2str(subject_id(i))
        % prefilename= strcat(sub_id,'-',test_id,'*')
        % prefilename=dir(prefilename)
        % filename=prefilename.name

        %% LOAD DATA
        TestResults=load(filename.name);

        %% RUN ANALYSIS 

        [wordspan_results]=analysis_WordSpan_Batch(TestResults,TestResults.results(1).RunTime.analysis.params);

        %% EXTRACT RTS
        wordspan_results;
        subject_id(i);
        subid=0;
        subid(1:size(wordspan_results),1)=subject_id(i);
        subid=table(subid);
        sub_output=[subid wordspan_results];
%         rtsdata=[subject_id(i) ResultsOutput(1).RunTime.analysis.results.anl]
%         Subj_outputdata(i,1)=rtsdata(1)
%         Subj_outputdata(i,j+1)=rtsdata(2)
%         test_id_header(:,j)=test_id(j)
             
        end
        sub_output
    end
    if length(filename)>0
    
    size_table=size(output);
    
    if size_table(2)==1
        output=sub_output;
    else
    output=[output;sub_output];
    end
%     outputdata(i,:)=
    end
end


writetable(output,'batch_wordspan.csv');


% filename = strcat('batch_wordspan.csv');
% 
% fid = fopen(filename, 'w');write(strcat('batch',test_id,'.csv'),headers)
% 
% fprintf(fid, 'Subject_ID ANL(SessionOne) ANL(SessionTwo)\n' );
% fclose(fid)
% 
% dlmwrite(filename, outputdata, '-append', 'precision', '%.6f', 'delimiter', '\t');

% %% MULTI-STAGE TEST
% %   Most implementations of HINT are seen as two-stage tests. We want the
% %   scoring to be based of the last segment (typically)
% runtime = results(end).RunTime;

