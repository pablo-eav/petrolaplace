/**
 * @file mex_root_free_reservoir.c
 * @brief MATLAB MEX Gateway for PetroLaplace™ C99 Reservoir Kernel.
 *
 * Syntax in MATLAB:
 *   [p_D, dp_D] = mex_root_free_reservoir(t_D, model_type, CD, S, omega, lambda, yeD, Sf, M)
 *
 * Inputs:
 *   t_D        - Double array of dimensionless times
 *   model_type - Integer model identifier (1: Storage/Skin, 2: Warren-Root, 3: MFHW)
 *   CD, S, ... - Physical parameters
 *   M          - Number of Talbot quadrature nodes (default = 32)
 *
 * Outputs:
 *   p_D        - Dimensionless pressure array
 *   dp_D       - Bourdet derivative array (t_D * dp_D / dt_D)
 *
 * Part of PetroLaplace™ Reservoir Core Toolbox.
 * Copyright (c) 2026 Prof. Pablo Enrique Aballe Vázquez.
 */

#include "mex.h"
#include "root_free_reservoir_core.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs < 2) {
        mexErrMsgIdAndTxt("petrolaplace:mex:minArgs", 
            "Usage: [p_D, dp_D] = mex_root_free_reservoir(t_D, model_type, [CD, S, omega, lambda, yeD, Sf, M])");
    }

    /* 1. Validate t_D input */
    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0])) {
        mexErrMsgIdAndTxt("petrolaplace:mex:invalidT", "t_D must be a real double array.");
    }
    size_t n_points = mxGetNumberOfElements(prhs[0]);
    double *t_array = mxGetPr(prhs[0]);

    /* 2. Model type */
    int model_type = (int)mxGetScalar(prhs[1]);

    /* 3. Parameters */
    ReservoirParams_t params;
    params.C_D = (nrhs > 2) ? mxGetScalar(prhs[2]) : 0.0;
    params.S   = (nrhs > 3) ? mxGetScalar(prhs[3]) : 0.0;
    params.omega = (nrhs > 4) ? mxGetScalar(prhs[4]) : 0.05;
    params.lambda_param = (nrhs > 5) ? mxGetScalar(prhs[5]) : 1e-6;
    params.y_eD = (nrhs > 6) ? mxGetScalar(prhs[6]) : 1.0;
    params.S_f  = (nrhs > 7) ? mxGetScalar(prhs[7]) : 0.0;

    int M = (nrhs > 8) ? (int)mxGetScalar(prhs[8]) : 32;
    if (M < 8) M = 8;
    if (M > 64) M = 64;

    /* 4. Allocate outputs */
    plhs[0] = mxCreateDoubleMatrix(1, (mwSize)n_points, mxREAL);
    double *p_out = mxGetPr(plhs[0]);

    double *dp_out = NULL;
    if (nlhs > 1) {
        plhs[1] = mxCreateDoubleMatrix(1, (mwSize)n_points, mxREAL);
        dp_out = mxGetPr(plhs[1]);
    }

    /* 5. Call C99 high-performance kernel */
    int status = rootfree_reservoir_invert_vector(
        t_array,
        p_out,
        dp_out,
        n_points,
        (ReservoirModelType_t)model_type,
        &params,
        M
    );

    if (status != ROOTFREE_RES_OK) {
        mexErrMsgIdAndTxt("petrolaplace:mex:kernelError", 
            "Kernel computation error, code: %d", status);
    }
}
