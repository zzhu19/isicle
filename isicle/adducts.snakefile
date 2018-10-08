from os.path import *
from resources.utils import *
import sys
import logging

# snakemake configuration
configfile: 'isicle/config.yaml'


rule desaltInChI:
    input:
        join(config['path'], 'input', '{id}.inchi')
    output:
        join(config['path'], 'output', 'desalted', '{id}.inchi')
    log:
        join(config['path'], 'output', 'desalted', 'logs', '{id}.log')
    benchmark:
        join(config['path'], 'output', 'desalted', 'benchmarks', '{id}.benchmark')
    # group:
    #     'adducts'
    run:
        inchi = read_string(input[0])
        inchi = desalt(inchi, log[0])
        if inchi is not None:
            write_string(inchi, output[0])
        else:
            sys.exit(1)

rule neutralizeInChI:
    input:
        rules.desaltInChI.output
    output:
        join(config['path'], 'output', 'neutralized', '{id}.inchi')
    benchmark:
        join(config['path'], 'output', 'neutralized', 'benchmarks', '{id}.benchmark')
    # group:
    #     'adducts'
    run:
        inchi = read_string(input[0])
        inchi = neutralize(inchi)
        if inchi is not None:
            write_string(inchi, output[0])
        else:
            sys.exit(1)

rule tautomerizeInChI:
    input:
        rules.neutralizeInChI.output
    output:
        join(config['path'], 'output', 'tautomer', '{id}.inchi')
    log:
        join(config['path'], 'output', 'tautomer', 'logs', '{id}.log')
    benchmark:
        join(config['path'], 'output', 'tautomer', 'benchmarks', '{id}.benchmark')
    # group:
    #     'adducts'
    run:
        inchi = read_string(input[0])
        inchi = tautomerize(inchi, log=log[0])
        if inchi is not None:
            write_string(inchi, output[0])
        else:
            sys.exit(1)

rule calculateFormula:
    input:
        rules.tautomerizeInChI.output
    output:
        join(config['path'], 'output', 'formula', '{id}.formula')
    log:
        join(config['path'], 'output', 'formula', 'logs', '{id}.log')
    benchmark:
        join(config['path'], 'output', 'formula', 'benchmarks', '{id}.benchmark')
    # group:
    #     'adducts'
    run:
        inchi = read_string(input[0])
        formula = inchi2formula(inchi, log=log[0])
        write_string(formula, output[0])

rule calculateMass:
    input:
        rules.calculateFormula.output
    output:
        join(config['path'], 'output', 'mass', '{id}.mass')
    benchmark:
        join(config['path'], 'output', 'mass', 'benchmarks', '{id}.benchmark')
    group:
        'adducts'
    shell:
        'python isicle/resources/molmass.py `cat {input}` > {output}'

rule generateGeometry:
    input:
        rules.tautomerizeInChI.output
    output:
        mol = join(config['path'], 'output', 'geometry_parent', '{id}.mol'),
        mol2 = join(config['path'], 'output', 'geometry_parent', '{id}.mol2'),
        xyz = join(config['path'], 'output', 'geometry_parent', '{id}.xyz'),
        png = join(config['path'], 'output', 'geometry_parent', 'images', '{id}.png')
    benchmark:
        join(config['path'], 'output', 'geometry_parent', 'benchmarks', '{id}.benchmark')
    # group:
    #     'adducts'
    run:
        inchi = read_string(input[0])
        mol = inchi2geom(inchi, forcefield=config['forcefield']['type'],
                         steps=config['forcefield']['steps'])

        mol.draw(show=False, filename=output.png, usecoords=False, update=False)
        mol.write('mol', output.mol, overwrite=True)
        mol.write('xyz', output.xyz, overwrite=True)
        mol.write('mol2', output.mol2, overwrite=True)

rule calculatepKa:
    input:
        rules.generateGeometry.output.mol
    output:
        join(config['path'], 'output', 'pKa', '{id}.pka')
    benchmark:
        join(config['path'], 'output', 'pKa', 'benchmarks', '{id}.benchmark')
    # group:
    #     'adducts'
    shell:
        'cxcalc pka -i -40 -x 40 -d large {input} > {output}'

rule generateAdducts:
    input:
        molfile = rules.generateGeometry.output.mol,
        pkafile = rules.calculatepKa.output
    output:
        xyz = join(config['path'], 'output', 'geometry_{adduct}', '{id}_{adduct}.xyz'),
        mol2 = join(config['path'], 'output', 'geometry_{adduct}', '{id}_{adduct}.mol2')
    log:
        join(config['path'], 'output', 'geometry_{adduct}', 'logs', '{id}_{adduct}.log')
    benchmark:
        join(config['path'], 'output', 'geometry_{adduct}', 'benchmarks', '{id}_{adduct}.benchmark')
    # group:
    #     'adducts'
    run:
        # log
        logging.basicConfig(filename=log[0], level=logging.DEBUG)

        # read inputs
        mol = next(pybel.readfile("mol", input[0]))
        pka = read_pka(input[1])

        # generate adduct
        a = wildcards.adduct
        if '+' in a:
            adduct = create_adduct(mol, a, pka['b1'],
                                   forcefield=config['forcefield']['type'],
                                   steps=config['forcefield']['steps'])
        elif '-' in a:
            adduct = create_adduct(mol, a, pka['a1'],
                                   forcefield=config['forcefield']['type'],
                                   steps=config['forcefield']['steps'])
        else:
            adduct = mol

        adduct.write('xyz', output.xyz, overwrite=True)
        adduct.write('mol2', output.mol2, overwrite=True)
