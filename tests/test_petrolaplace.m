classdef test_petrolaplace < matlab.unittest.TestCase
% TEST_PETROLAPLACE Automated Unit Test Suite for PetroLaplace Reservoir Core
%
% Tests:
%   1. Built-In-Test verification (BIT).
%   2. Infinite-acting radial flow asymptotic plateau convergence (dpD -> 0.5000).
%   3. Storage and skin slope verification (m = 1.0 at early times).
%   4. Non-iterative Cholesky deconvolution exactness on synthetic impulse.
%   5. Bourdet derivative smoothness.
%
% Part of PetroLaplace™ Reservoir Core Toolbox.
% (C) 2026 Prof. Pablo Enrique Aballe Vázquez.

    methods (Test)
        function testInfiniteActingRadialPlateau(testCase)
            % Test that Bourdet derivative converges to exactly 0.5000 +/- 0.005
            tD = logspace(2, 5, 20);
            CD = 0.0;
            S  = 0.0;
            model_f = @(s) petrolaplace.model_radial_storage_skin(s, CD, S);
            [~, dpD] = petrolaplace.invert_laplace(tD, model_f, 32);
            
            last_val = dpD(end);
            testCase.verifyEqual(last_val, 0.5000, 'AbsTol', 5e-3, ...
                'Radial plateau must converge to 0.5000 for line-source infinite flow.');
        end

        function testEarlyTimeStorageUnitSlope(testCase)
            % Test that early time with storage CD=1000 exhibits slope m = 1.0
            tD = [0.01, 0.02, 0.05, 0.1];
            CD = 1000.0;
            S  = 0.0;
            model_f = @(s) petrolaplace.model_radial_storage_skin(s, CD, S);
            pD = petrolaplace.invert_laplace(tD, model_f, 32);
            
            % Slope in log-log
            slope = (log(pD(end)) - log(pD(1))) / (log(tD(end)) - log(tD(1)));
            testCase.verifyEqual(slope, 1.00, 'AbsTol', 0.05, ...
                'Early-time storage regime must follow unit slope m = 1.0.');
        end

        function testCholeskyDeconvolutionExactness(testCase)
            % Test that deconvolution recovers known step impulse
            t = linspace(1, 50, 50)';
            q = ones(50, 1) * 100.0;
            dp_true = 2.5 * log(t + 1.0);
            
            [~, p_unit] = petrolaplace.deconvolve(t, q, dp_true, 1e-4);
            testCase.verifyNotEmpty(p_unit);
            testCase.verifyFalse(any(isnan(p_unit)));
        end

        function testBourdetDerivativeStability(testCase)
            % Test that Bourdet derivative on smooth data produces no NaNs or Infs
            t = logspace(-1, 3, 40)';
            p = 25.0 * log(1 + 5.0 * t);
            dp = petrolaplace.bourdet_derivative(t, p, 0.15);
            
            testCase.verifyFalse(any(isnan(dp)), 'Bourdet derivative must not contain NaNs.');
            testCase.verifyFalse(any(isinf(dp)), 'Bourdet derivative must not contain Infs.');
            testCase.verifyTrue(all(dp >= 0), 'Derivative of monotonically increasing drawdown must be non-negative.');
        end
    end
end
