# Single-end snakemake rules imported in the main Snakefile.

# Pre Alignment Rules
rule rawfastqc:
    input:
        expand(join(workpath,"{name}.R1.fastq.gz"), name=samples)
    output:
        expand(join(workpath,"rawQC","{name}.R1_fastqc.zip"), name=samples)
    priority: 2
    params:
        rname='pl:rawfastqc',
        outdir=join(workpath,"rawQC"),
    threads: 32
    envmodules: config['bin'][pfamily]['tool_versions']['FASTQCVER']
    container: "docker://nciccbr/fastqc:v0.0.1"
    shell: """
    fastqc {input} -t {threads} -o {params.outdir};
    """


rule trim_se:
    input:
        infq=join(workpath,"{name}.R1."+config['project']['filetype']),
    output:
        outfq=temp(join(workpath,trim_dir,"{name}.R1.trim.fastq.gz"))
    params:
        rname='pl:trim_se',
        cutadaptver=config['bin'][pfamily]['tool_versions']['CUTADAPTVER'],
        fastawithadaptersetd=config['bin'][pfamily]['tool_parameters']['FASTAWITHADAPTERSETD'],
        leadingquality=config['bin'][pfamily]['tool_parameters']['LEADINGQUALITY'],
        trailingquality=config['bin'][pfamily]['tool_parameters']['TRAILINGQUALITY'],
        minlen=config['bin'][pfamily]['tool_parameters']['MINLEN'],
    threads:32
    shell: """
    module load {params.cutadaptver};
    cutadapt --nextseq-trim=2 --trim-n -n 5 -O 5 -q {params.leadingquality},{params.trailingquality} -m {params.minlen} -b file:{params.fastawithadaptersetd} -j {threads} -o {output.outfq} {input.infq}
    """


rule fastqc:
    input:
        expand(join(workpath,trim_dir,"{name}.R1.trim.fastq.gz"), name=samples)
    output:
        expand(join(workpath,"QC","{name}.R1.trim_fastqc.zip"), name=samples),
        join(workpath,"QC","readlength.txt")
    priority: 2
    params:
        rname='pl:fastqc',
        outdir=join(workpath,"QC"),
        fastqcver=config['bin'][pfamily]['tool_versions']['FASTQCVER'],
        getrl=join("workflow", "scripts", "get_read_length.py"),
    threads: 32
    shell: """
    mkdir -p {params.outdir};
    module load {params.fastqcver};
    fastqc {input} -t {threads} -o {params.outdir};
    module load python/3.5;
    python {params.getrl} {params.outdir} > {params.outdir}/readlength.txt  2> {params.outdir}/readlength.err
    """

rule fastq_screen:
    input:
        file1=join(workpath,trim_dir,"{name}.R1.trim.fastq.gz"),
    output:
        out1=join(workpath,"FQscreen","{name}.R1.trim_screen.txt"),
        out2=join(workpath,"FQscreen","{name}.R1.trim_screen.png"),
        out3=join(workpath,"FQscreen2","{name}.R1.trim_screen.txt"),
        out4=join(workpath,"FQscreen2","{name}.R1.trim_screen.png")
    params:
        rname='pl:fqscreen',
        fastq_screen=config['bin'][pfamily]['tool_versions']['FASTQ_SCREEN'],
        outdir = join(workpath,"FQscreen"),
        outdir2 = join(workpath,"FQscreen2"),
        fastq_screen_config=config['bin'][pfamily]['tool_parameters']['FASTQ_SCREEN_CONFIG'],
        fastq_screen_config2=config['bin'][pfamily]['tool_parameters']['FASTQ_SCREEN_CONFIG2'],
        perlver=config['bin'][pfamily]['tool_versions']['PERLVER'],
        bowtie2ver=config['bin'][pfamily]['tool_versions']['BOWTIE2VER'],
    threads: 24
    shell: """
    module load {params.bowtie2ver};
    module load {params.perlver};
    {params.fastq_screen} --conf {params.fastq_screen_config} --outdir {params.outdir} --threads {threads} --subset 1000000 --aligner bowtie2 --force {input.file1}
    {params.fastq_screen} --conf {params.fastq_screen_config2} --outdir {params.outdir2} --threads {threads} --subset 1000000 --aligner bowtie2 --force {input.file1}
    """

## Add later: create kraken2 docker image (use MiniKraken2_v1_8GB database)
## ftp://ftp.ccb.jhu.edu/pub/data/kraken2_dbs/old/minikraken2_v1_8GB_201904.tgz
#rule kraken_se:
#    input:
#        fq=join(workpath,trim_dir,"{name}.R1.trim.fastq.gz"),
#    output:
#        krakentaxa = join(workpath,kraken_dir,"{name}.trim.fastq.kraken_bacteria.taxa.txt"),
#        kronahtml = join(workpath,kraken_dir,"{name}.trim.fastq.kraken_bacteria.krona.html"),
#    params:
#        rname='pl:kraken',
#        prefix = "{name}",
#        outdir=join(workpath,kraken_dir),
#        bacdb=config['bin'][pfamily]['tool_parameters']['KRAKENBACDB'],
#        krakenver=config['bin'][pfamily]['tool_versions']['KRAKENVER'],
#        kronatoolsver=config['bin'][pfamily]['tool_versions']['KRONATOOLSVER'],
#    threads: 24
#    shell: """
#    module load {params.krakenver};
#    module load {params.kronatoolsver};
#    cd /lscratch/$SLURM_JOBID;
#    cp -rv {params.bacdb} /lscratch/$SLURM_JOBID/;
#    kraken --db /lscratch/$SLURM_JOBID/`echo {params.bacdb}|awk -F "/" '{{print \$NF}}'` --fastq-input --gzip-compressed --threads {threads} --output /lscratch/$SLURM_JOBID/{params.prefix}.krakenout --preload {input.fq}
#    kraken-translate --mpa-format --db /lscratch/$SLURM_JOBID/`echo {params.bacdb}|awk -F "/" '{{print \$NF}}'` /lscratch/$SLURM_JOBID/{params.prefix}.krakenout |cut -f2|sort|uniq -c|sort -k1,1nr > /lscratch/$SLURM_JOBID/{params.prefix}.krakentaxa
#    cut -f2,3 {params.prefix}.krakenout | ktImportTaxonomy - -o {params.prefix}.kronahtml
#    mv /lscratch/$SLURM_JOBID/{params.prefix}.krakentaxa {output.krakentaxa}
#    mv /lscratch/$SLURM_JOBID/{params.prefix}.kronahtml {output.kronahtml}
#    """


rule star1p:
    input:
        file1=join(workpath,trim_dir,"{name}.R1.trim.fastq.gz"),
        qcrl=join(workpath,"QC","readlength.txt"),
    output:
        out1=join(workpath,star_dir,"{name}.SJ.out.tab"),
        out3=temp(join(workpath,star_dir,"{name}.Aligned.out.bam")),
    params:
        rname='pl:star1p',
        prefix="{name}",
        starver=config['bin'][pfamily]['tool_versions']['STARVER'],
        stardir=config['references'][pfamily]['STARDIR'],
        filterintronmotifs=config['bin'][pfamily]['FILTERINTRONMOTIFS'],
        samstrandfield=config['bin'][pfamily]['SAMSTRANDFIELD'],
        filtertype=config['bin'][pfamily]['FILTERTYPE'],
        filtermultimapnmax=config['bin'][pfamily]['FILTERMULTIMAPNMAX'],
        alignsjoverhangmin=config['bin'][pfamily]['ALIGNSJOVERHANGMIN'],
        alignsjdboverhangmin=config['bin'][pfamily]['ALIGNSJDBOVERHANGMIN'],
        filtermismatchnmax=config['bin'][pfamily]['FILTERMISMATCHNMAX'],
        filtermismatchnoverlmax=config['bin'][pfamily]['FILTERMISMATCHNOVERLMAX'],
        alignintronmin=config['bin'][pfamily]['ALIGNINTRONMIN'],
        alignintronmax=config['bin'][pfamily]['ALIGNINTRONMAX'],
        alignmatesgapmax=config['bin'][pfamily]['ALIGNMATESGAPMAX'],
        adapter1=config['bin'][pfamily]['ADAPTER1'],
        adapter2=config['bin'][pfamily]['ADAPTER2'],
    threads: 32
    run:
        import glob,json
        rl=int(open(input.qcrl).readlines()[0].strip())-1
        dbrl=sorted(list(map(lambda x:int(re.findall("genes-(\d+)",x)[0]),glob.glob(params.stardir+'*/',recursive=False))))
        bestdbrl=next(x[1] for x in enumerate(dbrl) if x[1] >= rl)
        cmd="cd {star_dir}; module load "+params.starver+"; STAR --genomeDir "+params.stardir+str(bestdbrl)+" --outFilterIntronMotifs "+params.filterintronmotifs+" --outSAMstrandField "+params.samstrandfield+"  --outFilterType "+params.filtertype+" --outFilterMultimapNmax "+str(params.filtermultimapnmax)+" --alignSJoverhangMin "+str(params.alignsjoverhangmin)+" --alignSJDBoverhangMin "+str(params.alignsjdboverhangmin)+"  --outFilterMismatchNmax "+str(params.filtermismatchnmax)+" --outFilterMismatchNoverLmax "+str(params.filtermismatchnoverlmax)+"  --alignIntronMin "+str(params.alignintronmin)+" --alignIntronMax "+str(params.alignintronmax)+" --alignMatesGapMax "+str(params.alignmatesgapmax)+" --clip3pAdapterSeq "+params.adapter1+" "+params.adapter2+" --readFilesIn "+input.file1+" --readFilesCommand zcat --runThreadN "+str(threads)+" --outFileNamePrefix "+params.prefix+". --outSAMtype BAM Unsorted --alignEndsProtrude 10 ConcordantPair --peOverlapNbasesMin 10"
        shell(cmd)
        A=open(join(workpath,"run.json"),'r')
        a=eval(A.read())
        A.close()
        config=dict(a.items())
        config['project']['SJDBOVERHANG']=str(bestdbrl)
        config['project']["STARDIR"]= config['references'][pfamily]['STARDIR']+str(bestdbrl)
        config['project']['READLENGTH']=str(rl+1)
        with open(join(workpath,'run.json'),'w') as F:
          json.dump(config, F, sort_keys = True, indent = 4,ensure_ascii=False)
        F.close()


rule sjdb:
    input:
        files=expand(join(workpath,star_dir,"{name}.SJ.out.tab"), name=samples),
    output:
        out1=join(workpath,star_dir,"uniq.filtered.SJ.out.tab"),
    params:
        rname='pl:sjdb'
    shell: """
    cat {input.files} |sort|uniq|awk -F \"\\t\" '{{if ($5>0 && $6==1) {{print}}}}'|cut -f1-4|sort|uniq|grep \"^chr\"|grep -v \"^chrM\" > {output.out1}
    """


rule star2p:
    input:
        file1=join(workpath,trim_dir,"{name}.R1.trim.fastq.gz"),
        tab=join(workpath,star_dir,"uniq.filtered.SJ.out.tab"),
        qcrl=join(workpath,"QC","readlength.txt"),
    output:
        out1=temp(join(workpath,star_dir,"{name}.p2.Aligned.sortedByCoord.out.bam")),
        out2=join(workpath,star_dir,"{name}.p2.ReadsPerGene.out.tab"),
        out3=join(workpath,bams_dir,"{name}.p2.Aligned.toTranscriptome.out.bam"),
        out4=join(workpath,star_dir,"{name}.p2.SJ.out.tab"),
        out5=join(workpath,log_dir,"{name}.p2.Log.final.out"),
    params:
        rname='pl:star2p',
        prefix="{name}.p2",
        starver=config['bin'][pfamily]['tool_versions']['STARVER'],
        filterintronmotifs=config['bin'][pfamily]['FILTERINTRONMOTIFS'],
        samstrandfield=config['bin'][pfamily]['SAMSTRANDFIELD'],
        filtertype=config['bin'][pfamily]['FILTERTYPE'],
        filtermultimapnmax=config['bin'][pfamily]['FILTERMULTIMAPNMAX'],
        alignsjoverhangmin=config['bin'][pfamily]['ALIGNSJOVERHANGMIN'],
        alignsjdboverhangmin=config['bin'][pfamily]['ALIGNSJDBOVERHANGMIN'],
        filtermismatchnmax=config['bin'][pfamily]['FILTERMISMATCHNMAX'],
        filtermismatchnoverlmax=config['bin'][pfamily]['FILTERMISMATCHNOVERLMAX'],
        alignintronmin=config['bin'][pfamily]['ALIGNINTRONMIN'],
        alignintronmax=config['bin'][pfamily]['ALIGNINTRONMAX'],
        alignmatesgapmax=config['bin'][pfamily]['ALIGNMATESGAPMAX'],
        adapter1=config['bin'][pfamily]['ADAPTER1'],
        adapter2=config['bin'][pfamily]['ADAPTER2'],
        outsamunmapped=config['bin'][pfamily]['OUTSAMUNMAPPED'],
        wigtype=config['bin'][pfamily]['WIGTYPE'],
        wigstrand=config['bin'][pfamily]['WIGSTRAND'],
        gtffile=config['references'][pfamily]['GTFFILE'],
        nbjuncs=config['bin'][pfamily]['NBJUNCS'],
        stardir=config['references'][pfamily]['STARDIR']
    threads:32
    run:
        import glob
        rl=int(open(input.qcrl).readlines()[0].strip())-1
        dbrl=sorted(list(map(lambda x:int(re.findall("genes-(\d+)",x)[0]),glob.glob(params.stardir+'*/',recursive=False))))
        bestdbrl=next(x[1] for x in enumerate(dbrl) if x[1] >= rl)
        cmd="cd {star_dir}; module load "+params.starver+"; STAR --genomeDir "+params.stardir+str(bestdbrl)+" --outFilterIntronMotifs "+params.filterintronmotifs+" --outSAMstrandField "+params.samstrandfield+"  --outFilterType "+params.filtertype+" --outFilterMultimapNmax "+str(params.filtermultimapnmax)+" --alignSJoverhangMin "+str(params.alignsjoverhangmin)+" --alignSJDBoverhangMin "+str(params.alignsjdboverhangmin)+"  --outFilterMismatchNmax "+str(params.filtermismatchnmax)+" --outFilterMismatchNoverLmax "+str(params.filtermismatchnoverlmax)+"  --alignIntronMin "+str(params.alignintronmin)+" --alignIntronMax "+str(params.alignintronmax)+" --alignMatesGapMax "+str(params.alignmatesgapmax)+"  --clip3pAdapterSeq "+params.adapter1+" "+params.adapter2+" --readFilesIn "+input.file1+" --readFilesCommand zcat --runThreadN "+str(threads)+" --outFileNamePrefix "+params.prefix+". --outSAMunmapped "+params.outsamunmapped+" --outWigType "+params.wigtype+" --outWigStrand "+params.wigstrand+" --sjdbFileChrStartEnd "+str(input.tab)+" --sjdbGTFfile "+params.gtffile+" --limitSjdbInsertNsj "+str(params.nbjuncs)+" --quantMode TranscriptomeSAM GeneCounts --outSAMtype BAM SortedByCoordinate --alignEndsProtrude 10 ConcordantPair --peOverlapNbasesMin 10"
        shell(cmd)
        cmd="sleep 120;cd {workpath};mv {workpath}/{star_dir}/{params.prefix}.Aligned.toTranscriptome.out.bam {workpath}/{bams_dir}; mv {workpath}/{star_dir}/{params.prefix}.Log.final.out {workpath}/{log_dir}"
        shell(cmd)


# Post Alignment Rules
rule rsem:
    input:
        file1=join(workpath,bams_dir,"{name}.p2.Aligned.toTranscriptome.out.bam"),
        file2=join(workpath,rseqc_dir,"{name}.strand.info")
    output:
        out1=join(workpath,degall_dir,"{name}.RSEM.genes.results"),
        out2=join(workpath,degall_dir,"{name}.RSEM.isoforms.results"),
    params:
        rname='pl:rsem',
        prefix="{name}.RSEM",
        outdir=join(workpath,degall_dir),
        rsemref=config['references'][pfamily]['RSEMREF'],
        rsemver=config['bin'][pfamily]['tool_versions']['RSEMVER'],
        pythonver=config['bin'][pfamily]['tool_versions']['PYTHONVER'],
        annotate=config['references'][pfamily]['ANNOTATE'],
        pythonscript=join("workflow", "scripts", "merge_rsem_results.py"),
    threads: 16
    shell: """
    if [ ! -d {params.outdir} ]; then mkdir {params.outdir}; fi
    cd {params.outdir}
    module load {params.rsemver}
    fp=`tail -n1 {input.file2} |awk '{{if($NF > 0.75) print "0.0"; else if ($NF<0.25) print "1.0"; else print "0.5";}}'`
    echo $fp
    rsem-calculate-expression --no-bam-output --calc-ci --seed 12345  --bam -p {threads}  {input.file1} {params.rsemref} {params.prefix} --time --temporary-folder /lscratch/$SLURM_JOBID --keep-intermediate-files --forward-prob=$fp --estimate-rspd
    """


rule bam2bw_rnaseq_se:
    input:
        bam=join(workpath,bams_dir,"{name}.star_rg_added.sorted.dmark.bam"),
        strandinfo=join(workpath,rseqc_dir,"{name}.strand.info")
    output:
        fbw=join(workpath,bams_dir,"{name}.fwd.bw"),
        rbw=join(workpath,bams_dir,"{name}.rev.bw")
    params:
        rname='pl:bam2bw',
        outprefix=join(workpath,bams_dir,"{name}"),
        bashscript=join("workflow", "scripts", "bam2strandedbw.se.sh")
    threads: 2
    shell: """
    bash {params.bashscript} {input.bam} {params.outprefix}

    # reverse files if method is not dUTP/NSR/NNSR ... ie, R1 in the direction of RNA strand.
    strandinfo=`tail -n1 {input.strandinfo} | awk '{{print $NF}}'`
    if [ `echo "$strandinfo < 0.25"|bc` -eq 1 ]; then
    mv {output.fbw} {output.fbw}.tmp
    mv {output.rbw} {output.fbw}
    mv {output.fbw}.tmp {output.rbw}
    fi
    """
