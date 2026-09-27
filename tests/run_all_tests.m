function results = run_all_tests()
% RUN_ALL_TESTS Executes the complete automated test suite for PetroLaplace Toolbox
%
% Syntax:
%   run_all_tests
%   results = run_all_tests
%
% Part of PetroLaplace™ Reservoir Core Toolbox.
% (C) 2026 Prof. Pablo Enrique Aballe Vázquez.

fprintf('=================================================================\n');
fprintf('     PETROLAPLACE RESERVOIR CORE - AUTOMATED TEST RUNNER         \n');
fprintf('=================================================================\n\n');

suite = matlab.unittest.TestSuite.fromClass(?test_petrolaplace);
runner = matlab.unittest.TestRunner.withTextOutput();
results = runner.run(suite);

fprintf('\n=================================================================\n');
if all([results.Passed])
    fprintf(' [PASS] All %d test cases passed successfully!\n', length(results));
else
    fprintf(' [FAIL] Some test cases failed. Check output above.\n');
end
fprintf('=================================================================\n');

end
