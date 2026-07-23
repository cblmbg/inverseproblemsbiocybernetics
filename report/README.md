# Technical report

The main LaTeX source is:

```text
inverse_ladder_case_study_report.tex
```

Compile from this folder with:

```text
pdflatex inverse_ladder_case_study_report.tex
pdflatex inverse_ladder_case_study_report.tex
```

Regenerate the report figures in MATLAB with:

```matlab
generateReportFigures
```

The figure generator loads the verified result file from the parent case-study
folder and writes publication-quality PNG files to `figures/`.
