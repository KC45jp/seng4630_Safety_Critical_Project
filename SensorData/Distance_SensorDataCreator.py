import csv
import random

rows = 100

def create_patterned_file(filename, include_letters):
    # Default counts
    num_c = 0
    num_f = 0

    if 'C' in include_letters:
        num_c = 20
    if 'F' in include_letters:
        num_f = 20

    # Remaining rows for N/W
    num_nw = rows - num_c - num_f

    # Generate N/W mix (only if included)
    nw_choices = [l for l in ['N', 'W'] if l in include_letters]
    nw_letters = [random.choice(nw_choices) for _ in range(num_nw)] if nw_choices else []

    # Build final sequence
    letters_sequence = nw_letters + ['C'] * num_c + ['F'] * num_f

    # Shuffle ONLY for case 2 if you want randomness in placement
    if include_letters == ['N', 'W', 'C']:
        random.shuffle(letters_sequence)

    # Write file
    with open(filename, mode='w', newline='') as file:
        writer = csv.writer(file)

        for letter in letters_sequence:
            #  CASE 2 ONLY: inject occasional empty data rows
            if include_letters == ['N', 'W', 'C'] and random.random() < 0.1:
                writer.writerow(['', ''])  # produces (,)
                continue
            value1 = round(random.uniform(0, 100), 2)
            writer.writerow([value1, letter])

def write_scenarios():

    # 1. Only N (no grouping needed)
    create_patterned_file('Senario1/DistanceSensorData.csv', ['N'])

    # 2. N, W, C (C grouped at end)
    create_patterned_file('Senario2/DistanceSensorData.csv', ['N', 'W', 'C'])

    # 3. N, W, C, F (C then F at end)
    create_patterned_file('Senario3/DistanceSensorData.csv', ['N', 'W', 'C', 'F'])

    print("three CSV files created for Distance sensor.")