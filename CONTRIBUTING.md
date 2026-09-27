# Contributing to PetroLaplace™ Reservoir Core

Thank you for your interest in contributing to **PetroLaplace™ Reservoir Core**!

## Guidelines for Contributions

1. **Bug Reports & Issues:**
   - Please open a GitHub Issue describing your environment (OS, MATLAB version, Python version, C compiler).
   - If reporting a discrepancy in well test matching, please attach a minimal reproducible example (time, rate, pressure series).

2. **Pull Requests:**
   - Fork the repository and create your feature branch: `git checkout -b feature/my-new-feature`.
   - Ensure your code follows the MISRA-C99 guidelines (for C code: 0 `malloc`, strict typing, zero compiler warnings with `/W4` or `-Wall -Wextra`).
   - For MATLAB code, ensure compliance with the `+petrolaplace` namespace and run `tests/run_all_tests.m`.
   - Commit your changes: `git commit -am 'Add new analytical model'`.
   - Push to the branch: `git push origin feature/my-new-feature`.
   - Submit a Pull Request.

3. **Intellectual Property Notice:**
   - All contributions accepted into the core engine become part of the PetroLaplace codebase under its dual licensing framework. By submitting a pull request, you confirm that you hold the necessary rights to contribute the code.

For commercial inquiries, custom model developments, or enterprise support, please contact the author directly.
