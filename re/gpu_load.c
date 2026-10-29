// GameOS RE — charge GPU headless (OpenCL) pour forcer la GTX 1080 Ti à monter
// en fréquence (P8/P2 -> P0) pendant une capture mmiotrace. Pas besoin d'écran.
//   gpu_load <secondes>
// Compilation : cc -O2 gpu_load.c -o gpu_load -lOpenCL   (paquet opencl-headers requis)
#define CL_TARGET_OPENCL_VERSION 120
#include <CL/cl.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Noyau volontairement gourmand : longue boucle de FMA, sans accès mémoire,
// pour saturer les unités de calcul et déclencher la montée en fréquence.
static const char *SRC =
"__kernel void burn(__global float *out, const int iters){\n"
"  float a = get_global_id(0)*1e-3f, b = 1.0001f;\n"
"  for(int i=0;i<iters;i++){ a = a*b + 0.5f; b = b*1.0000003f + 1e-7f; }\n"
"  out[get_global_id(0)] = a + b;\n"
"}\n";

#define CK(x) do{ cl_int _e=(x); if(_e){ fprintf(stderr,"OpenCL err %d @%d\n",_e,__LINE__); return 2; } }while(0)

int main(int argc, char **argv){
    int secs = argc > 1 ? atoi(argv[1]) : 12;
    cl_platform_id plat; cl_device_id dev;
    CK(clGetPlatformIDs(1, &plat, NULL));
    CK(clGetDeviceIDs(plat, CL_DEVICE_TYPE_GPU, 1, &dev, NULL));
    cl_int e;
    cl_context ctx = clCreateContext(NULL, 1, &dev, NULL, NULL, &e); CK(e);
    cl_command_queue q = clCreateCommandQueue(ctx, dev, 0, &e); CK(e);
    cl_program prog = clCreateProgramWithSource(ctx, 1, &SRC, NULL, &e); CK(e);
    if (clBuildProgram(prog, 1, &dev, NULL, NULL, NULL)) {
        char log[8192]; clGetProgramBuildInfo(prog, dev, CL_PROGRAM_BUILD_LOG, sizeof log, log, NULL);
        fprintf(stderr, "build: %s\n", log); return 2;
    }
    cl_kernel k = clCreateKernel(prog, "burn", &e); CK(e);
    size_t N = 1 << 20;
    cl_mem out = clCreateBuffer(ctx, CL_MEM_WRITE_ONLY, N * sizeof(float), NULL, &e); CK(e);
    int iters = 200000;
    CK(clSetKernelArg(k, 0, sizeof(out), &out));
    CK(clSetKernelArg(k, 1, sizeof(iters), &iters));

    fprintf(stderr, "charge GPU %d s…\n", secs);
    time_t end = time(NULL) + secs;
    while (time(NULL) < end) {
        CK(clEnqueueNDRangeKernel(q, k, 1, NULL, &N, NULL, 0, NULL, NULL));
        CK(clFinish(q));   // bloque jusqu'à la fin : charge soutenue
    }
    clReleaseMemObject(out); clReleaseKernel(k);
    clReleaseProgram(prog); clReleaseCommandQueue(q); clReleaseContext(ctx);
    fprintf(stderr, "fin de charge\n");
    return 0;
}
