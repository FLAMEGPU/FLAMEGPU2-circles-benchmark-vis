#! /usr/bin/env python3
import seaborn as sns
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.image as mpimg
import argparse
import pathlib


# Default DPI
DEFAULT_DPI = 300

# Default directory for visualisation images
DEFAULT_INPUT_DIR="."

# Default directory for visualisation images
DEFAULT_VISUALISATION_DIR = "./sample/figures/visualisation"

# Visualisation images used in the figure (4 required)
VISUALISATION_IMAGE_FILENAMES = ['0.png', '350.png', '650.png', '2500.png']

# Drift csv filename from simulation output
DRIFT_CSV_FILENAME = "drift_perStepPerSimulationCSV.csv"

def cli():
    parser = argparse.ArgumentParser(description="Python script to generate figure from csv files")

    parser.add_argument(
        '-o', 
        '--output-dir', 
        type=str, 
        help='directory to output figures into.',
        default='.'
    )
    parser.add_argument(
        '--dpi', 
        type=int, 
        help='DPI for output file',
        default=DEFAULT_DPI
    )

    parser.add_argument(
        '-i',
        '--input-dir', 
        type=str, 
        help='Input directory, containing the csv files',
        default='.'
    )
    
    parser.add_argument(
        '-v',
        '--vis-dir', 
        type=str, 
        help="Input directory, containing the visualisation files",
        default=DEFAULT_VISUALISATION_DIR
    )

    args = parser.parse_args()
    return args

def validate_args(args):
    valid = True

    # If output_dir is passed, create it, error if can't create it.
    if args.output_dir is not None:
        p = pathlib.Path(args.output_dir)
        try:
            p.mkdir(exist_ok=True)
        except Exception as e:
            print(f"Error: Could not create output directory {p}: {e}")
            valid = False

    # DPI must be positive, and add a max.
    if args.dpi is not None:
        if args.dpi < 1:
            print(f"Error: --dpi must be a positive value. {args.dpi}")
            valid = False

    # Ensure that the input directory exists, and that all required input is present.
    if args.input_dir is not None:
        input_dir = pathlib.Path(args.input_dir) 
        if input_dir.is_dir():
            csv_path = input_dir / DRIFT_CSV_FILENAME
            if not csv_path.is_file():
                print(f"Error: {input_dir} does not contain {DRIFT_CSV_FILENAME}:")
        else:
            print(f"Error: Invalid input_dir provided {args.input_dir}")
            valid = False
        
    # Ensure that the visualisation input directory exists, and that all required images are present.
    vis_dir = pathlib.Path(args.vis_dir) 
    if vis_dir.is_dir():
        missing_files = []
        for vis_filename in VISUALISATION_IMAGE_FILENAMES:
            vis_file_path = vis_dir / vis_filename
            if not vis_file_path.is_file():
                missing_files.append(vis_file_path)
                valid = False
        if len(missing_files) > 0:
            print(f"Error: {vis_dir} does not contain required files:")
            for missing_file in missing_files:
                print(f"  {missing_file}")
    else:
        print(f"Error: Invalid vis_dir provided {args.vis_dir}")
        valid = False
        
    # Additional check on number of visualisation files
    if len(VISUALISATION_IMAGE_FILENAMES) != 4:
        print(f"Error: VISUALISATION_IMAGE_FILENAMES does not contain 4 files")
        valid = False

    return valid


def main():

    # Validate cli
    args = cli()
    valid_args = validate_args(args)
    if not valid_args:
        return False
            
    # Set figure theme
    sns.set_theme(style='white')
    
    # setup sub plot using mosaic layout
    gs_kw = dict(width_ratios=[2, 1, 1], height_ratios=[1, 1])
    f, ax = plt.subplot_mosaic([['drift', 'v1', 'v2'],
                                ['drift', 'v3', 'v4']],
                                  gridspec_kw=gs_kw, figsize=(10, 5),
                                  constrained_layout=True)
    
    
    # Load per time step data into data frame
    input_dir = pathlib.Path(args.input_dir) 
    step_df = pd.read_csv(input_dir/DRIFT_CSV_FILENAME, sep=',', quotechar='"')
    # Strip any white space from column names
    step_df.columns = step_df.columns.str.strip()
    # rename comm_radius to 'r'
    step_df.rename(columns={'comm_radius': 'r'}, inplace=True)

    # Plot group by communication radius (r)
    plt_drift = sns.lineplot(x='step', y='s_drift', hue='r', data=step_df, ax=ax['drift'])
    plt_drift.set(xlabel='Simulation steps', ylabel='Mean drift')
    ax['drift'].set_title(label='A', loc='left', fontweight="bold")
    
    # visualisation path
    visualisation_dir = pathlib.Path(args.vis_dir) 
    
    # Plot vis for time step = 0
    v1 = mpimg.imread(visualisation_dir / VISUALISATION_IMAGE_FILENAMES[0]) 
    ax['v1'].imshow(v1)
    ax['v1'].set_axis_off()
    ax['v1'].set_title(label='B', loc='left', fontweight="bold")
    
    # Plot vis for time step = 350
    v1 = mpimg.imread(visualisation_dir / VISUALISATION_IMAGE_FILENAMES[1]) 
    ax['v2'].imshow(v1)
    ax['v2'].set_axis_off()
    ax['v2'].set_title(label='C', loc='left', fontweight="bold")
    
    # Plot vis for time step = 850
    v1 = mpimg.imread(visualisation_dir / VISUALISATION_IMAGE_FILENAMES[2]) 
    ax['v3'].imshow(v1)
    ax['v3'].set_axis_off()
    ax['v3'].set_title(label='D', loc='left', fontweight="bold")
    
    # Plot vis for time step = 2500
    v1 = mpimg.imread(visualisation_dir / VISUALISATION_IMAGE_FILENAMES[3]) 
    ax['v4'].imshow(v1)
    ax['v4'].set_axis_off()
    ax['v4'].set_title(label='E', loc='left', fontweight="bold")
    
    # Save to image
    #f.tight_layout()
    output_dir = pathlib.Path(args.output_dir) 
    f.savefig(output_dir/"figure.png", dpi=args.dpi) 
    f.savefig(output_dir/"figure.pdf", format='pdf', dpi=args.dpi) 


# Run the main method if this was not included as a module
if __name__ == "__main__":
    main()
