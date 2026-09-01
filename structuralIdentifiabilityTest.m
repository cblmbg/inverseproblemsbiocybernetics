classdef structuralIdentifiabilityTest < matlab.unittest.TestCase
    %STRUCTURALIDENTIFIABILITYTEST Fast validation of the shared runner API.

    methods (Test)
        function testEmptyOptionListIsRejected(testCase)
            operation = @() runStrikeGolddAnalyses(strings(0, 1), false);

            testCase.verifyError(operation, ...
                "InverseLadder:EmptyStrikeOptions");
        end

        function testMissingOptionFileIsRejected(testCase)
            operation = @() runStrikeGolddAnalyses( ...
                "options_that_do_not_exist.m", false);

            testCase.verifyError(operation, ...
                "InverseLadder:MissingStrikeOptions");
        end
    end
end
