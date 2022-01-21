#include <algorithm>
#include <cstdio>
#include <chrono>
#include <ctime>

#include "flamegpu/flamegpu.h"
#include "common.cuh"
#include "util.cuh"

#define DRY_RUN 0

// Prototypes for methods from other .cu files
void run_circles_spatial3D(const RunSimulationInputs runInputs, RunSimulationOutputs &runOutputs);

bool run_experiment(
    const std::string LABEL,
    const int DEVICE,
    const uint32_t REPETITIONS,
    std::vector<RunSimulationInputs> INPUTS_STRUCTS,
    std::map<std::string, std::function<void(const RunSimulationInputs, RunSimulationOutputs&)>> MODELS,
    const bool dry 
) { 
    printf("Running experiment %s - %zu configs, %zu simulators, %u repetitions\n", LABEL.c_str(), INPUTS_STRUCTS.size(), MODELS.size(), REPETITIONS);

    // Open CSV files
    std::string filename_perSimulationCSV = LABEL + std::string("_perSimulationCSV.csv");
    std::FILE * fp_perSimulationCSV = std::fopen(filename_perSimulationCSV.c_str(), "w");
    if(fp_perSimulationCSV == nullptr) {
        printf("Error: could not open csv file %s\n", filename_perSimulationCSV.c_str());
        std::fclose(fp_perSimulationCSV);
        return false;
    }
    std::string filename_perStepPerSimulationCSV = LABEL + std::string("_perStepPerSimulationCSV.csv");
    std::FILE * fp_perStepPerSimulationCSV = std::fopen(filename_perStepPerSimulationCSV.c_str(), "w");
    if(fp_perStepPerSimulationCSV == nullptr) {
        printf("Error: could not open csv file %s\n", filename_perStepPerSimulationCSV.c_str());
        std::fclose(fp_perSimulationCSV);
        std::fclose(fp_perStepPerSimulationCSV);
        return false;
    }

    // Output the CSV header for each output CSV file.
    if (fp_perSimulationCSV) {
        fprintf(fp_perSimulationCSV, "GPU,release_mode,seatbelts_on,model,steps,agent_count,env_width,comm_radius,repeat,agent_density,mean_message_count,s_rtc,s_simulation,s_init,s_exit,s_step_mean\n");
    }
        
    if (fp_perStepPerSimulationCSV) {
        fprintf(fp_perStepPerSimulationCSV, "GPU,release_mode,seatbelts_on,model,steps,agent_count,env_width,comm_radius,repeat,agent_density,step,s_step, s_drift, s_messages\n");
    }


    const std::string deviceName = getGPUName(DEVICE);
    
    
    const uint32_t totalSimulationCount = static_cast<uint32_t>(INPUTS_STRUCTS.size() * MODELS.size() * REPETITIONS);
    uint32_t simulationIdx = 0; 
    
    // For each input structure
    for (const auto& inputStruct : INPUTS_STRUCTS) {
        for (const auto& modelNameFunctionPair : MODELS) {
            auto const& modelName = modelNameFunctionPair.first;
            auto const& modelFunction = modelNameFunctionPair.second; 
            for (uint32_t repeatIdx = 0u; repeatIdx < REPETITIONS; repeatIdx++){
                // Output progress
                printProgress(
                    modelName, 
                    simulationIdx, 
                    totalSimulationCount, 
                    inputStruct.AGENT_COUNT, 
                    inputStruct.ENV_WIDTH, 
                    inputStruct.COMM_RADIUS, 
                    repeatIdx);

                // Only print the progress if a dry run.
                if (dry) { 
                    continue;
                }

                // Run the simulation, capturing values for output.
                const RunSimulationInputs runInputs = {
                    DEVICE,
                    inputStruct.STEPS, 
                    inputStruct.SEED + repeatIdx,
                    inputStruct.AGENT_COUNT, 
                    inputStruct.ENV_WIDTH,
                    inputStruct.COMM_RADIUS
                };
                RunSimulationOutputs runOutputs = {};
                modelFunction(runInputs, runOutputs);

                // Add a row to the row per simulation csv file
                if (fp_perSimulationCSV) {
                    fprintf(
                        fp_perSimulationCSV, 
                        "%s,%d,%d,%s,%u,%u,%.3f,%.3f,%u,%.3f,%.3f,%.3f\n",
                        deviceName.c_str(),
                        isReleaseMode(),
                        isSeatbeltsON(),
                        modelName.c_str(),
                        inputStruct.STEPS,
                        inputStruct.AGENT_COUNT,
                        inputStruct.ENV_WIDTH,
                        inputStruct.COMM_RADIUS,
                        repeatIdx,
                        runOutputs.agentDensity,
                        runOutputs.mean_messageCount,
                        runOutputs.s_stepMean); 
                }
                // Add a row to the per step per simulation CSV
                if (fp_perStepPerSimulationCSV) {
                    for(uint32_t step = 0; step < runOutputs.s_per_step->size(); step++){
                        auto& s_step = runOutputs.s_per_step->at(step);
                        auto& s_drift = runOutputs.drift_per_step->at(step);
                        auto& s_messages = runOutputs.messages_per_step->at(step);
                        fprintf(fp_perStepPerSimulationCSV,
                            "%s,%d,%d,%s,%u,%u,%.3f,%.3f,%u,%.3f,%u,%.6f,%.6f,%.3f\n",
                            deviceName.c_str(),
                            isReleaseMode(),
                            isSeatbeltsON(),
                            modelName.c_str(),
                            inputStruct.STEPS,
                            inputStruct.AGENT_COUNT,
                            inputStruct.ENV_WIDTH,
                            inputStruct.COMM_RADIUS,
                            repeatIdx,
                            runOutputs.agentDensity,
                            step,
                            s_step,
                            s_drift,
                            s_messages);
                    }
                }
                simulationIdx++;
            }
        }
    }
    
    // Close csv file handles.
    if(fp_perSimulationCSV){
        std::fclose(fp_perSimulationCSV);
        fp_perSimulationCSV = nullptr; 
    }
    if(fp_perStepPerSimulationCSV) {
        std::fclose(fp_perStepPerSimulationCSV);
        fp_perStepPerSimulationCSV = nullptr; 
    }

    return true;
}


bool experiment_drift(custom_cli cli) {
    // Name the experiment - this will end up in filenames/paths.
    const std::string EXPERIMENT_LABEL = "drift";

    const uint32_t popSize = 64000;
    const float ENV_WIDTH = 40.0f;

    const std::vector<float> comm_radii = { 1.0f, 2.0f, 3.0f, 4.0f, 5.0f };

    // Select the models to execute.
    std::map<std::string, std::function<void(const RunSimulationInputs, RunSimulationOutputs&)>> MODELS = {
        {std::string("circles_spatial3D"), run_circles_spatial3D}
    };

    // Construct the vector of RunSimulationInputs to pass to the run_experiment method.
    auto INPUTS_STRUCTS = std::vector<RunSimulationInputs>();
    for (const auto& comm_radius : comm_radii) {
        // Envwidth is scaled with population size.
        INPUTS_STRUCTS.push_back({
            cli.device,
            cli.steps, // override the default number of steps
            cli.seed,
            popSize,
            ENV_WIDTH,
            comm_radius 
            });
    }

    // Run the experriment
    bool success = run_experiment(
        EXPERIMENT_LABEL,
        cli.device,
        cli.repetitions,
        INPUTS_STRUCTS,
        MODELS,
        cli.dry
    );

    return success;
}


#ifdef VISUALISATION
bool experiment_visualisation(custom_cli cli) {
    // Name the experiment - this will end up in filenames/paths.
    const std::string EXPERIMENT_LABEL = "drift";

    const uint32_t popSize = 64000;
    const float ENV_WIDTH = 40.0f;

    // Select the models to execute.
    std::map<std::string, std::function<void(const RunSimulationInputs, RunSimulationOutputs&)>> MODELS = {
        {std::string("circles_spatial3D"), run_circles_spatial3D}
    };

    // Construct the vector of RunSimulationInputs to pass to the run_experiment method.
    auto INPUTS_STRUCTS = std::vector<RunSimulationInputs>();

    // Envwidth is scaled with population size.
    INPUTS_STRUCTS.push_back({
        cli.device,
        cli.steps,
        cli.seed,
        popSize,
        ENV_WIDTH,
        DEFAULT_VISUALISATION_RADIUS   // fixed com radius
        });


    // Run the experriment
    bool success = run_experiment(
        EXPERIMENT_LABEL,
        cli.device,
        1, // single repitition
        INPUTS_STRUCTS,
        MODELS,
        cli.dry
    );

    return success;
}
#endif


int main(int argc, const char ** argv) {
    // Custom arg parsing, to prevent the current F2 arg parsing from occuring. 
    custom_cli cli = parse_custom_cli(argc, argv);

#ifdef VISUALISATION
    return experiment_visualisation(cli);
#else
    return experiment_drift(cli);
#endif
}
