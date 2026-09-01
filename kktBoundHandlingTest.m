classdef kktBoundHandlingTest < matlab.unittest.TestCase
    %KKTBOUNDHANDLINGTEST Unit tests for constrained simplex-weight inference.

    methods (Test)
        function testLowerBoundSign(testCase)
            cfg = defaultInverseLadderConfig();
            cfg.inverse.kktGradientTolerance = 0;

            result = inferSimplexWeights(zeros(0, 2), cfg, ...
                LowerBoundMatrix=[1 -3]);

            testCase.verifyGreaterThanOrEqual(result.weights(1), ...
                0.75 - 1e-8);
            testCase.verifyTrue(result.kktCompatible);
            testCase.verifyEqual(result.lowerActiveRowCount, 1);
        end

        function testUpperBoundSign(testCase)
            cfg = defaultInverseLadderConfig();
            cfg.inverse.kktGradientTolerance = 0;

            result = inferSimplexWeights(zeros(0, 2), cfg, ...
                UpperBoundMatrix=[3 -1]);

            testCase.verifyLessThanOrEqual(result.weights(1), 0.25 + 1e-8);
            testCase.verifyTrue(result.kktCompatible);
            testCase.verifyEqual(result.upperActiveRowCount, 1);
        end

        function testOpposedBoundSignsIdentifyWeights(testCase)
            cfg = defaultInverseLadderConfig();
            cfg.inverse.kktGradientTolerance = 0;

            result = inferSimplexWeights(zeros(0, 2), cfg, ...
                LowerBoundMatrix=[1 -1], UpperBoundMatrix=[1 -1]);

            testCase.verifyEqual(result.weights, [0.5; 0.5], AbsTol=1e-8);
            testCase.verifyTrue(result.locallyIdentifiable);
            testCase.verifyLessThanOrEqual(result.maximumWeightRange, ...
                cfg.inverse.weightRangeTolerance);
        end

        function testRegularizerDoesNotCreateIdentification(testCase)
            cfg = defaultInverseLadderConfig();

            result = inferSimplexWeights(zeros(0, 4), cfg);

            testCase.verifyEqual(result.weights, 0.25*ones(4, 1), ...
                AbsTol=1e-8);
            testCase.verifyFalse(result.dataIdentifiable);
            testCase.verifyFalse(result.locallyIdentifiable);
            testCase.verifyEqual(result.maximumWeightRange, 1, AbsTol=1e-8);
        end

        function testIncompatibleBoundRowsAreReported(testCase)
            cfg = defaultInverseLadderConfig();
            cfg.inverse.kktGradientTolerance = 0;

            result = inferSimplexWeights(zeros(0, 2), cfg, ...
                LowerBoundMatrix=[-1 -1]);

            testCase.verifyLessThanOrEqual(result.exitFlag, 0);
            testCase.verifyLessThanOrEqual(result.dataExitFlag, 0);
            testCase.verifyFalse(result.kktCompatible);
            testCase.verifyFalse(result.locallyIdentifiable);
        end

        function testKktMatrixWidthIsValidated(testCase)
            cfg = defaultInverseLadderConfig();

            operation = @() inferSimplexWeights(zeros(0, 3), cfg, ...
                LowerBoundMatrix=zeros(1, 2));

            testCase.verifyError(operation, "InverseLadder:KktMatrixSize");
        end

        function testDefaultUpperLevelsRemainStable(testCase)
            cfg = defaultInverseLadderConfig();
            expectedLevel3 = [0.619535; 0.140022; 0.140500; 0.099943];
            expectedLevel4 = [ ...
                0.576999, 0.619045; ...
                0.217618, 0.250175; ...
                0.058953, 0.050456; ...
                0.146429, 0.080323];

            level3 = runLevel3InverseOptimalControl(cfg, cfg.trueParameters);
            level4 = runLevel4InverseDifferentialGame(cfg, cfg.trueParameters);

            testCase.verifyEqual(level3.inferredWeights, expectedLevel3, ...
                AbsTol=5e-5);
            testCase.verifyEqual(level4.inferredWeights, expectedLevel4, ...
                AbsTol=5e-5);
            testCase.verifyEqual(level3.status, "verified");
            testCase.verifyEqual(level4.status, "verified");
            testCase.verifyTrue(level3.kktCompatible);
            testCase.verifyTrue(all(level4.kktCompatible));
            testCase.verifyEqual([level3.interiorRowCount, ...
                level3.lowerActiveRowCount, level3.upperActiveRowCount], ...
                [27, 2, 3]);
            testCase.verifyEqual(level4.interiorRowCount, [16, 8]);
            testCase.verifyEqual(level4.lowerActiveRowCount, [0, 8]);
            testCase.verifyEqual(level4.upperActiveRowCount, [0, 0]);
        end
    end
end
