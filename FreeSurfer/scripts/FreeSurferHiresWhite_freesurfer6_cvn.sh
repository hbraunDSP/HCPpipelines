#!/bin/bash
set -e
echo -e "\n START: FreeSurferHighResWhite"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)

export SUBJECTS_DIR="$SubjectDIR"

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf

echo "$SubjectID" > "$mridir"/transforms/eye.dat
echo "1" >> "$mridir"/transforms/eye.dat
echo "1" >> "$mridir"/transforms/eye.dat
echo "1" >> "$mridir"/transforms/eye.dat
echo "1 0 0 0" >> "$mridir"/transforms/eye.dat
echo "0 1 0 0" >> "$mridir"/transforms/eye.dat
echo "0 0 1 0" >> "$mridir"/transforms/eye.dat
echo "0 0 0 1" >> "$mridir"/transforms/eye.dat
echo "round" >> "$mridir"/transforms/eye.dat

reg=$mridir/transforms/eye.dat
regII=$mridir/transforms/eye.dat
#fslmaths "$T1wImage" -abs -add 1 "$mridir"/T1w_hires.nii.gz
#hires="$mridir"/T1w_hires.nii.gz

# make sure to create the file control.hires.dat in the scripts dir with at least a few points
# in the wm for the mri_normalize call that comes next

# remove nonbrain tissue
mri_mask $T1wImage $mridir/brain.mgz $mridir/T1.masked.mgz

mri_convert $mridir/aseg.mgz $mridir/aseg.nii.gz
leftcoords=`fslstats $mridir/aseg.nii.gz -l 1 -u 3 -c`
rightcoords=`fslstats $mridir/aseg.nii.gz -l 40 -u 42 -c`

echo "$leftcoords" > $SubjectDIR/$SubjectID/scripts/control.dat
echo "$rightcoords" >> $SubjectDIR/$SubjectID/scripts/control.dat
echo "info" >> $SubjectDIR/$SubjectID/scripts/control.dat
echo "numpoints 2" >> $SubjectDIR/$SubjectID/scripts/control.dat
echo "useRealRAS 1" >> $SubjectDIR/$SubjectID/scripts/control.dat

# do intensity normalization on the hires volume using the white surface
mri_normalize -erode 1 -f $SubjectDIR/$SubjectID/scripts/control.dat -min_dist 1 -surface "$surfdir"/lh.white identity.nofile -surface "$surfdir"/rh.white identity.nofile $mridir/T1.masked.mgz $mridir/T1.masked.norm.mgz

# Check if FreeSurfer is version 5.2.0 or not.  If it is not, use new -first_wm_peak mris_make_surfaces flag
if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then  #Not using v5.2.0
  FIRSTWMPEAK="-first_wm_peak"
else  #Using v5.2.0
  FIRSTWMPEAK=""
fi

. ~/SetUpFreeSurfer.sh hcp
#deform the white surfaces (i.e., tweak white surfaces using hires inputs)
#Note that the ".deformed" suffix that is appended through use of -output flag is hard-coded into FreeSurferHiresPial.sh as well.
mris_make_surfaces ${FIRSTWMPEAK} -whiteonly -noaparc -aseg aseg -orig white -filled filled -wm wm -sdir $SubjectDIR -T1 T1.masked.norm -orig_white white -output .deformed -w 0 $SubjectID lh
mris_make_surfaces ${FIRSTWMPEAK} -whiteonly -noaparc -aseg aseg -orig white -filled filled -wm wm -sdir $SubjectDIR -T1 T1.masked.norm -orig_white white -output .deformed -w 0 $SubjectID rh


###Fine Tune T2w to T1w Registration


if [ ! -e "$mridir"/transforms/T2wtoT1w.mat ] ; then
  bbregister --s "$SubjectID" --mov "$T2wImage" --surf white.deformed --init-reg "$mridir"/transforms/eye.dat --t2 --reg "$mridir"/transforms/T2wtoT1w.dat --o "$mridir"/T2.nii.gz
  tkregister2 --noedit --reg "$mridir"/transforms/T2wtoT1w.dat --mov "$T2wImage" --targ "$mridir"/T1.nii.gz --fslregout "$mridir"/transforms/T2wtoT1w.mat
  applywarp --interp=spline -i "$T2wImage" -r "$mridir"/T1.nii.gz --premat="$mridir"/transforms/T2wtoT1w.mat -o "$mridir"/T2.nii.gz
  fslmaths "$mridir"/T2.nii.gz -abs -add 1 "$mridir"/T2.nii.gz
  fslmaths "$mridir"/T1.nii.gz -mul "$mridir"/T2.nii.gz -sqrt "$mridir"/T1wMulT2w.nii.gz
else
  echo "Warning Reruning FreeSurfer Pipeline"
  echo "T2w to T1w Registration Will Not Be Done Again"
  echo "Verify that "$T2wImage" has not been fine tuned and then remove "$mridir"/transforms/T2wtoT1w.mat"
fi

# Create version of white surfaces back in the 1mm (FS conformed) space
#tkregister2 --mov $mridir/orig.mgz --targ "$mridir"/T1w_hires.nii.gz --noedit --regheader --reg $regII
mri_surf2surf --s $SubjectID --sval-xyz white.deformed --reg $regII $mridir/orig.mgz --tval-xyz --tval white --surfreg white --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz white.deformed --reg $regII $mridir/orig.mgz --tval-xyz --tval white --surfreg white --hemi rh


# Copy the ".deformed" outputs of previous mris_make_surfaces to their default FS file names
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.curv.deformed $SubjectDIR/$SubjectID/surf/lh.curv
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.area.deformed  $SubjectDIR/$SubjectID/surf/lh.area
cp --preserve=timestamps $SubjectDIR/$SubjectID/label/lh.cortex.deformed.label $SubjectDIR/$SubjectID/label/lh.cortex.label
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.curv.deformed $SubjectDIR/$SubjectID/surf/rh.curv
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.area.deformed  $SubjectDIR/$SubjectID/surf/rh.area
cp --preserve=timestamps $SubjectDIR/$SubjectID/label/rh.cortex.deformed.label $SubjectDIR/$SubjectID/label/rh.cortex.label


echo -e "\n END: FreeSurferHighResWhite"

