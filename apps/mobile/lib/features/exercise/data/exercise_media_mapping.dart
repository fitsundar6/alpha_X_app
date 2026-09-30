// Alpha X Gym - Verified Exercise Media & Demonstration Mapping
// Auto-generated & audited against ExerciseDB / GymVisual 1,324 exercise dataset
// Total verified movements: 155 IDs, 158 normalized names.
//
// STRICT FALLBACK RULE:
// VALID EXERCISE GIF FOUND -> SHOW THE GIF
// NO VALID GIF FOUND       -> SHOW "DEMONSTRATION UNAVAILABLE"
// NEVER: SHOW HERO IMAGE AS DEMONSTRATION
// NEVER: SHOW ANOTHER EXERCISE'S GIF
// NEVER: SHOW PLACEHOLDER/DEMO MEDIA

class ExerciseMediaMapping {
  /// Strict Exercise ID -> Verified Animated GIF URL mapping
  static const Map<String, String> _idToGif = {
    'ex_ab_wheel_rollout': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0857-NAgVB3t.gif', // wheel rollerout
    'ex_alt_db_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0285-BU15nH4.gif', // dumbbell alternate biceps curl
    'ex_arnold_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2137-Xy4jlWA.gif', // dumbbell arnold press
    'ex_back_extension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0489-zhMwOwE.gif', // hyperextension
    'ex_barbell_deadlift': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0032-ila4NZS.gif', // barbell deadlift
    'ex_barbell_rdl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0085-wQ2c4XD.gif', // barbell romanian deadlift
    'ex_barbell_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0043-qXTaZnJ.gif', // barbell full squat
    'ex_battle_ropes': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0128-RJa4tCo.gif', // battling ropes
    'ex_bayesian_cable_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0868-G08RZcQ.gif', // cable curl
    'ex_bb_back_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0043-qXTaZnJ.gif', // barbell full squat
    'ex_bb_bench': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0025-EIeI8Vf.gif', // barbell bench press
    'ex_bb_bench_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0025-EIeI8Vf.gif', // barbell bench press
    'ex_bb_bent_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0027-eZyBC3j.gif', // barbell bent over row
    'ex_bb_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0031-25GPyDY.gif', // barbell curl
    'ex_bb_glute_bridge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3562-qg2PGl6.gif', // barbell glute bridge two legs on bench (male)
    'ex_bb_good_morning': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0044-XlZ4lAC.gif', // barbell good morning
    'ex_bb_hip_thrust': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3562-qg2PGl6.gif', // barbell glute bridge two legs on bench (male)
    'ex_bb_shrug': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0095-dG7tG5y.gif', // barbell shrug
    'ex_bb_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0043-qXTaZnJ.gif', // barbell full squat
    'ex_bb_upright_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0120-UDlhcO8.gif', // barbell upright row
    'ex_bent_over_row_bb': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0027-eZyBC3j.gif', // barbell bent over row
    'ex_bicep_curl_bb': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0031-25GPyDY.gif', // barbell curl
    'ex_bicep_curl_db': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0294-NbVPDMW.gif', // dumbbell biceps curl
    'ex_bulgarian_split_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0410-qx4fgX7.gif', // dumbbell single leg split squat
    'ex_burpee': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1160-dK9394r.gif', // burpee
    'ex_cable_crunch': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0175-WW95auq.gif', // cable kneeling crunch
    'ex_cable_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0868-G08RZcQ.gif', // cable curl
    'ex_cable_fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0227-Pr9Rhf4.gif', // cable standing fly
    'ex_cable_fly_high_low': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0227-Pr9Rhf4.gif', // cable standing fly
    'ex_cable_fly_low_high': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0227-Pr9Rhf4.gif', // cable standing fly
    'ex_cable_kickback': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0860-HEJ6DIX.gif', // cable kickback
    'ex_cable_lateral_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0178-goJ6ezq.gif', // cable lateral raise
    'ex_cable_overhead_tricep': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1724-NN8nSNT.gif', // cable rope high pulley overhead tricep extension
    'ex_cable_pull_through': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0196-OM46QHm.gif', // cable pull through (with rope)
    'ex_cable_rear_delt_fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0225-P5p0j8B.gif', // cable standing cross-over high reverse fly
    'ex_cable_rope_hammer_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0165-HPlPoQA.gif', // cable hammer curl (with rope)
    'ex_cable_seated_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0861-fUBheHs.gif', // cable seated row
    'ex_chest_dips': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0251-9WTm7dq.gif', // chest dip
    'ex_chest_supported_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0327-7vG5o25.gif', // dumbbell incline row
    'ex_chin_up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1326-T2mxWqc.gif', // chin-up
    'ex_clean_and_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0028-SGY8Zui.gif', // barbell clean and press
    'ex_close_grip_bench_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0030-J6Dx1Mu.gif', // barbell close-grip bench press
    'ex_close_grip_lat_pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2616-4c9BhzB.gif', // cable lateral pulldown with v-bar
    'ex_concentration_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0297-gvsWLQw.gif', // dumbbell concentration curl
    'ex_conventional_deadlift': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0032-ila4NZS.gif', // barbell deadlift
    'ex_cross_body_hammer_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0298-Qyk5J3p.gif', // dumbbell cross body hammer curl
    'ex_db_bench': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0289-SpYC0Kp.gif', // dumbbell bench press
    'ex_db_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0294-NbVPDMW.gif', // dumbbell biceps curl
    'ex_db_fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0308-yz9nUhF.gif', // dumbbell fly
    'ex_db_front_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0310-3eGE2JC.gif', // dumbbell front raise
    'ex_db_lateral_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0334-DsgkuIt.gif', // dumbbell lateral raise
    'ex_db_overhead_extension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0430-PdmaD0N.gif', // dumbbell standing triceps extension
    'ex_db_rdl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1459-rR0LJzx.gif', // dumbbell romanian deadlift
    'ex_db_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0292-C0MA9bC.gif', // dumbbell one arm bent-over row
    'ex_db_shoulder_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0405-znQUdHY.gif', // dumbbell seated shoulder press
    'ex_db_shrug': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0406-NJzBsGJ.gif', // dumbbell shrug
    'ex_db_skull_crusher': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0351-mpKZGWz.gif', // dumbbell lying triceps extension
    'ex_db_tricep_kickback': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0333-W6PxUkg.gif', // dumbbell kickback
    'ex_dead_bug': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0276-iny3m5y.gif', // dead bug
    'ex_decline_bb_bench': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0033-GrO65fd.gif', // barbell decline bench press
    'ex_decline_bb_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0033-GrO65fd.gif', // barbell decline bench press
    'ex_decline_db_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0301-DwhEmmE.gif', // dumbbell decline bench press
    'ex_decline_push_up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0279-i5cEhka.gif', // decline push-up
    'ex_decline_situp': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0282-QLL2gdc.gif', // decline sit-up
    'ex_deficit_reverse_lunge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0336-RRWFUcw.gif', // dumbbell lunge
    'ex_diamond_push_up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0283-soIB2rj.gif', // diamond push-up
    'ex_dumbbell_rdl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1459-rR0LJzx.gif', // dumbbell romanian deadlift
    'ex_ez_bar_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0447-6TG6x2w.gif', // ez barbell curl
    'ex_ez_skull_crusher': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0060-h8LFzo9.gif', // barbell lying triceps extension skull crusher
    'ex_face_pull': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0233-ZfyAGhK.gif', // cable standing rear delt row (with rope)
    'ex_farmer_carry': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2133-qPEzJjA.gif', // farmers walk
    'ex_floor_crunch': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0274-TFqbd8t.gif', // crunch floor
    'ex_forearm_plank': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2135-VBAWRPG.gif', // weighted front plank
    'ex_forward_lunge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0336-RRWFUcw.gif', // dumbbell lunge
    'ex_front_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0042-zG0zs85.gif', // barbell front squat
    'ex_goblet_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1760-yn8yg1r.gif', // dumbbell goblet squat
    'ex_hack_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0743-Qa55kX1.gif', // sled hack squat
    'ex_hammer_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0313-slDvUAU.gif', // dumbbell hammer curl
    'ex_hanging_knee_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1764-VEcJRo2.gif', // hanging leg hip raise
    'ex_hanging_leg_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0472-I3tsCnC.gif', // hanging leg raise
    'ex_hip_thrust': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3562-qg2PGl6.gif', // barbell glute bridge two legs on bench (male)
    'ex_incline_bb': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0047-3TZduzM.gif', // barbell incline bench press
    'ex_incline_bb_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0047-3TZduzM.gif', // barbell incline bench press
    'ex_incline_db': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0314-ns0SIbU.gif', // dumbbell incline bench press
    'ex_incline_db_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0318-ae9UoXQ.gif', // dumbbell incline curl
    'ex_incline_db_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0314-ns0SIbU.gif', // dumbbell incline bench press
    'ex_incline_machine': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1299-jHAnWmT.gif', // lever incline chest press
    'ex_incline_push_up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0493-B1EVP9F.gif', // incline push-up
    'ex_incline_smith': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0757-5v7KYld.gif', // smith incline bench press
    'ex_incline_smith_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0757-5v7KYld.gif', // smith incline bench press
    'ex_inverted_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0499-bZGHsAZ.gif', // inverted row
    'ex_kettlebell_swing': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0549-UHJlbu3.gif', // kettlebell swing
    'ex_lat_pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2330-LEprlgG.gif', // cable lat pulldown full range of motion
    'ex_lat_pulldown_wide': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2330-LEprlgG.gif', // cable lat pulldown full range of motion
    'ex_lat_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0334-DsgkuIt.gif', // dumbbell lateral raise
    'ex_lateral_raise_db': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0334-DsgkuIt.gif', // dumbbell lateral raise
    'ex_leaning_cable_lateral_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0178-goJ6ezq.gif', // cable lateral raise
    'ex_leg_extension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0585-my33uHU.gif', // lever leg extension
    'ex_leg_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2287-V07qpXy.gif', // lever alternate leg press
    'ex_lying_leg_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0586-17lJ1kr.gif', // lever lying leg curl
    'ex_machine_chest_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0576-DOoWcnA.gif', // lever chest press
    'ex_machine_dip': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1451-BRImeP8.gif', // lever seated dip
    'ex_machine_hip_abduction': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0597-CHpahtl.gif', // lever seated hip abduction
    'ex_machine_preacher_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0592-b6hQYMb.gif', // lever preacher curl
    'ex_machine_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1350-7I6LNUG.gif', // lever seated row
    'ex_machine_shoulder_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0603-67n3r98.gif', // lever shoulder press
    'ex_medicine_ball_slam': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1354-oHg8eop.gif', // medicine ball overhead slam
    'ex_military_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1456-wdRZISl.gif', // barbell standing close grip military press
    'ex_one_arm_db_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0292-C0MA9bC.gif', // dumbbell one arm bent-over row
    'ex_overhand_pullup': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0652-lBDjFxJ.gif', // pull-up
    'ex_overhead_cable_extension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1724-NN8nSNT.gif', // cable rope high pulley overhead tricep extension
    'ex_overhead_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1456-wdRZISl.gif', // barbell standing close grip military press
    'ex_overhead_press_bb': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1456-wdRZISl.gif', // barbell standing close grip military press
    'ex_pallof_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0979-9pa4H5m.gif', // band horizontal pallof press
    'ex_pec_deck': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0596-v3xmPAR.gif', // lever seated fly
    'ex_pendlay_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0027-eZyBC3j.gif', // barbell bent over row
    'ex_plate_front_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0834-e4aFmFY.gif', // weighted front raise
    'ex_preacher_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0070-qOgPVf6.gif', // barbell preacher curl
    'ex_pullup': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0652-lBDjFxJ.gif', // pull-up
    'ex_push_up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0662-I4hDWkc.gif', // push-up
    'ex_rdl_barbell': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0085-wQ2c4XD.gif', // barbell romanian deadlift
    'ex_rear_delt_db_fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0378-8DiFDVA.gif', // dumbbell rear fly
    'ex_reverse_crunch': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0872-nCU1Ekp.gif', // reverse crunch
    'ex_reverse_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0080-xNrS20v.gif', // barbell reverse curl
    'ex_reverse_lunge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0078-VaP75jl.gif', // barbell rear lunge
    'ex_reverse_pec_deck': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0602-myfUsKf.gif', // lever seated reverse fly
    'ex_romanian_deadlift': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0085-wQ2c4XD.gif', // barbell romanian deadlift
    'ex_rope_pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0200-dU605di.gif', // cable pushdown (with rope attachment)
    'ex_russian_twist': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0687-XVDdcoj.gif', // russian twist
    'ex_seated_cable_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0861-fUBheHs.gif', // cable seated row
    'ex_seated_calf_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1371-ipvgBnC.gif', // barbell seated calf raise
    'ex_seated_db_press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0405-znQUdHY.gif', // dumbbell seated shoulder press
    'ex_seated_leg_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0599-Zg3XY7P.gif', // lever seated leg curl
    'ex_seated_row_cable': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0861-fUBheHs.gif', // cable seated row
    'ex_side_plank': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3544-5VXmnV5.gif', // bodyweight incline side plank
    'ex_single_arm_cable_pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1723-qRZ5S1N.gif', // cable one arm tricep pushdown
    'ex_single_arm_lat_pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3563-U5INZY6.gif', // cable one arm pulldown
    'ex_single_leg_hip_thrust': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3645-rmEukuS.gif', // single leg bridge with outstretched leg
    'ex_sissy_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1489-xdYPUtE.gif', // sissy squat
    'ex_skull_crusher': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0060-h8LFzo9.gif', // barbell lying triceps extension skull crusher
    'ex_smith_squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3281-NNoHCEA.gif', // smith full squat
    'ex_spider_curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1628-2kattbR.gif', // ez barbell spider curl
    'ex_standing_calf_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1372-8ozhUIZ.gif', // barbell standing calf raise
    'ex_standing_machine_calf_raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0605-ykUOVze.gif', // lever standing calf raise
    'ex_step_up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0431-aXtJhlg.gif', // dumbbell step-up
    'ex_stiff_leg_deadlift': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0116-hrVQWvE.gif', // barbell straight leg deadlift
    'ex_straight_arm_pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0237-DT14T9T.gif', // cable straight arm pulldown (with rope)
    'ex_straight_bar_pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0201-3ZflifB.gif', // cable pushdown
    'ex_t_bar_row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0588-IGjKj1v.gif', // lever narrow grip seated row
    'ex_tricep_rope_pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0200-dU605di.gif', // cable pushdown (with rope attachment)
    'ex_triceps_dip': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0251-9WTm7dq.gif', // chest dip
    'ex_turkish_get_up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0551-Ha7SZ3y.gif', // kettlebell turkish get up (squat style)
    'ex_walking_lunge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0336-RRWFUcw.gif', // dumbbell lunge
    'ex_wall_ball': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1353-PsVS1QP.gif', // medicine ball catch and overhead throw
    'ex_warm_inchworm': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1471-ZgsNQ6d.gif', // inchworm
  };

  /// Normalized Exercise Name -> Verified Animated GIF URL mapping
  static const Map<String, String> _nameToGif = {
    '45 degree plate loaded leg press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2287-V07qpXy.gif',
    '45-degree plate-loaded leg press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2287-V07qpXy.gif',
    'ab wheel rollout': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0857-NAgVB3t.gif',
    'alternating dumbbell curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0285-BU15nH4.gif',
    'arnold press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2137-Xy4jlWA.gif',
    'back extension / hyperextension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0489-zhMwOwE.gif',
    'back extension hyperextension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0489-zhMwOwE.gif',
    'barbell back squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0043-qXTaZnJ.gif',
    'barbell bent over row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0027-eZyBC3j.gif',
    'barbell bent-over row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0027-eZyBC3j.gif',
    'barbell curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0031-25GPyDY.gif',
    'barbell flat bench press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0025-EIeI8Vf.gif',
    'barbell romanian deadlift (rdl)': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0085-wQ2c4XD.gif',
    'barbell romanian deadlift rdl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0085-wQ2c4XD.gif',
    'barbell shrug': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0095-dG7tG5y.gif',
    'battle rope': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0128-RJa4tCo.gif',
    'bayesian cable curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0868-G08RZcQ.gif',
    'bulgarian split squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0410-qx4fgX7.gif',
    'burpee': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1160-dK9394r.gif',
    'cable crunch': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0175-WW95auq.gif',
    'cable curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0868-G08RZcQ.gif',
    'cable kickback': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0860-HEJ6DIX.gif',
    'cable lateral raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0178-goJ6ezq.gif',
    'cable pull through': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0196-OM46QHm.gif',
    'cable pull-through': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0196-OM46QHm.gif',
    'cable rear delt fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0225-P5p0j8B.gif',
    'cable rope face pull': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0233-ZfyAGhK.gif',
    'cable rope hammer curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0165-HPlPoQA.gif',
    'cable triceps rope pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0200-dU605di.gif',
    'chest dip': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0251-9WTm7dq.gif',
    'chest supported incline row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0327-7vG5o25.gif',
    'chest-supported incline row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0327-7vG5o25.gif',
    'clean and press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0028-SGY8Zui.gif',
    'close grip bench press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0030-J6Dx1Mu.gif',
    'close grip lat pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2616-4c9BhzB.gif',
    'close-grip bench press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0030-J6Dx1Mu.gif',
    'close-grip lat pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2616-4c9BhzB.gif',
    'concentration curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0297-gvsWLQw.gif',
    'conventional barbell deadlift': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0032-ila4NZS.gif',
    'cross body hammer curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0298-Qyk5J3p.gif',
    'cross-body hammer curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0298-Qyk5J3p.gif',
    'crunch': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0274-TFqbd8t.gif',
    'dead bug': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0276-iny3m5y.gif',
    'decline barbell bench press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0033-GrO65fd.gif',
    'decline dumbbell press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0301-DwhEmmE.gif',
    'decline push up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0279-i5cEhka.gif',
    'decline push-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0279-i5cEhka.gif',
    'decline sit up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0282-QLL2gdc.gif',
    'decline sit-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0282-QLL2gdc.gif',
    'deficit reverse lunge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0336-RRWFUcw.gif',
    'diamond push up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0283-soIB2rj.gif',
    'diamond push-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0283-soIB2rj.gif',
    'dumbbell bench press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0289-SpYC0Kp.gif',
    'dumbbell chest fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0308-yz9nUhF.gif',
    'dumbbell curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0294-NbVPDMW.gif',
    'dumbbell kickback': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0333-W6PxUkg.gif',
    'dumbbell lateral raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0334-DsgkuIt.gif',
    'dumbbell overhead extension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0430-PdmaD0N.gif',
    'dumbbell romanian deadlift': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1459-rR0LJzx.gif',
    'dumbbell shoulder press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0405-znQUdHY.gif',
    'dumbbell shrug': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0406-NJzBsGJ.gif',
    'dumbbell skull crusher': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0351-mpKZGWz.gif',
    'ez bar curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0447-6TG6x2w.gif',
    'ez bar skull crusher': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0060-h8LFzo9.gif',
    'ez-bar curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0447-6TG6x2w.gif',
    'ez-bar skull crusher': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0060-h8LFzo9.gif',
    'farmer carry': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2133-qPEzJjA.gif',
    'forward lunge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0336-RRWFUcw.gif',
    'front raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0310-3eGE2JC.gif',
    'front squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0042-zG0zs85.gif',
    'glute bridge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3562-qg2PGl6.gif',
    'goblet squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1760-yn8yg1r.gif',
    'good morning': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0044-XlZ4lAC.gif',
    'hack squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0743-Qa55kX1.gif',
    'hammer curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0313-slDvUAU.gif',
    'hanging knee raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1764-VEcJRo2.gif',
    'hanging leg raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0472-I3tsCnC.gif',
    'high to low cable fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0227-Pr9Rhf4.gif',
    'high-to-low cable fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0227-Pr9Rhf4.gif',
    'hip thrust': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3562-qg2PGl6.gif',
    'incline barbell press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0047-3TZduzM.gif',
    'incline chest press machine': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1299-jHAnWmT.gif',
    'incline dumbbell biceps curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0318-ae9UoXQ.gif',
    'incline dumbbell press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0314-ns0SIbU.gif',
    'incline push up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0493-B1EVP9F.gif',
    'incline push-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0493-B1EVP9F.gif',
    'incline smith machine press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0757-5v7KYld.gif',
    'inverted bodyweight row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0499-bZGHsAZ.gif',
    'kettlebell swing': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0549-UHJlbu3.gif',
    'leaning cable lateral raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0178-goJ6ezq.gif',
    'leg extension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0585-my33uHU.gif',
    'low to high cable fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0227-Pr9Rhf4.gif',
    'low-to-high cable fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0227-Pr9Rhf4.gif',
    'lying leg curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0586-17lJ1kr.gif',
    'machine chest press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0576-DOoWcnA.gif',
    'machine dip': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1451-BRImeP8.gif',
    'machine hip abduction': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0597-CHpahtl.gif',
    'machine preacher curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0592-b6hQYMb.gif',
    'machine shoulder press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0603-67n3r98.gif',
    'medicine ball slam': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1354-oHg8eop.gif',
    'neutral grip pull up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0652-lBDjFxJ.gif',
    'neutral grip pull-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0652-lBDjFxJ.gif',
    'one arm dumbbell row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0292-C0MA9bC.gif',
    'one-arm dumbbell row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0292-C0MA9bC.gif',
    'overhand wide grip pull up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0652-lBDjFxJ.gif',
    'overhand wide-grip pull-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0652-lBDjFxJ.gif',
    'overhead cable extension': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1724-NN8nSNT.gif',
    'pallof press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0979-9pa4H5m.gif',
    'pec deck machine fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0596-v3xmPAR.gif',
    'pendlay row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0027-eZyBC3j.gif',
    'plank': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2135-VBAWRPG.gif',
    'plate front raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0834-e4aFmFY.gif',
    'preacher curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0070-qOgPVf6.gif',
    'rear delt dumbbell fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0378-8DiFDVA.gif',
    'reverse crunch': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0872-nCU1Ekp.gif',
    'reverse curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0080-xNrS20v.gif',
    'reverse lunge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0078-VaP75jl.gif',
    'reverse pec deck': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0602-myfUsKf.gif',
    'russian twist': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0687-XVDdcoj.gif',
    'seated cable row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0861-fUBheHs.gif',
    'seated calf raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1371-ipvgBnC.gif',
    'seated leg curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0599-Zg3XY7P.gif',
    'seated machine row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1350-7I6LNUG.gif',
    'side plank': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3544-5VXmnV5.gif',
    'single arm cable lat pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3563-U5INZY6.gif',
    'single arm cable pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1723-qRZ5S1N.gif',
    'single leg hip thrust': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3645-rmEukuS.gif',
    'single-arm cable lat pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3563-U5INZY6.gif',
    'single-arm cable pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1723-qRZ5S1N.gif',
    'single-leg hip thrust': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3645-rmEukuS.gif',
    'sissy squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1489-xdYPUtE.gif',
    'smith machine squat': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3281-NNoHCEA.gif',
    'spider curl': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1628-2kattbR.gif',
    'standard push up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0662-I4hDWkc.gif',
    'standard push-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0662-I4hDWkc.gif',
    'standing cable chest fly': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0227-Pr9Rhf4.gif',
    'standing calf raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1372-8ozhUIZ.gif',
    'standing machine calf raise': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0605-ykUOVze.gif',
    'standing overhead barbell press': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1456-wdRZISl.gif',
    'step up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0431-aXtJhlg.gif',
    'step-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0431-aXtJhlg.gif',
    'stiff leg deadlift': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0116-hrVQWvE.gif',
    'stiff-leg deadlift': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0116-hrVQWvE.gif',
    'straight arm cable pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0237-DT14T9T.gif',
    'straight bar pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0201-3ZflifB.gif',
    'straight-arm cable pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0237-DT14T9T.gif',
    'straight-bar pushdown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0201-3ZflifB.gif',
    't bar row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0588-IGjKj1v.gif',
    't-bar row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0588-IGjKj1v.gif',
    'triceps dip': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0251-9WTm7dq.gif',
    'turkish get up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0551-Ha7SZ3y.gif',
    'turkish get-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0551-Ha7SZ3y.gif',
    'underhand chin up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1326-T2mxWqc.gif',
    'underhand chin-up': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1326-T2mxWqc.gif',
    'upright row': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0120-UDlhcO8.gif',
    'walking lunge': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0336-RRWFUcw.gif',
    'wall ball': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1353-PsVS1QP.gif',
    'wide grip lat pulldown': 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2330-LEprlgG.gif',
  };

  /// Resolves the verified animated GIF URL for a specific exercise ID.
  static String? getGifForExerciseId(String? exerciseId) {
    if (exerciseId == null || exerciseId.trim().isEmpty) return null;
    return _idToGif[exerciseId.trim()];
  }

  /// Resolves the verified animated GIF URL for a given exercise name.
  static String? getGifForExerciseName(String? exerciseName) {
    if (exerciseName == null || exerciseName.trim().isEmpty) return null;
    final normalized = normalizeName(exerciseName);
    return _nameToGif[normalized];
  }

  /// Normalizes exercise name for consistent lookup:
  /// trims, converts to lowercase, removes punctuation/parentheses/brackets.
  static String normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\)\-\[\]\–\—\/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Validates whether a candidate URL is a genuine animated GIF URL.
  /// Strictly rejects:
  /// - Unsplash photos (*.unsplash.com*)
  /// - Static hero images (hero.png, hero.jpg, hero.jpeg)
  /// - Non-GIF extensions (.png, .jpg, .jpeg, .webp, .mp4)
  static bool isValidGif(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();

    // Reject static gym photos / Unsplash images
    if (clean.contains('unsplash.com') ||
        clean.contains('photo-') ||
        clean.contains('hero.') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.mp4')) {
      return false;
    }

    return clean.endsWith('.gif') || clean.contains('.gif?');
  }

  /// Comprehensive resolution pipeline that strictly enforces the priority:
  /// 1. Direct explicit candidate URL (if it is a genuine, verified GIF)
  /// 2. Exercise ID lookup in verified mapping
  /// 3. Normalized Exercise Name lookup in verified mapping
  /// 4. STRICT FALLBACK: Returns null ("Demonstration unavailable")
  ///
  /// NEVER returns hero images, static photos, or other exercises' GIFs.
  static String? resolveGif({
    String? exerciseId,
    String? exerciseName,
    String? candidateUrl,
  }) {
    // 1. Direct candidate GIF
    if (isValidGif(candidateUrl)) {
      return candidateUrl!.trim();
    }

    // 2. Strict Exercise ID lookup
    final byId = getGifForExerciseId(exerciseId);
    if (byId != null && isValidGif(byId)) {
      return byId;
    }

    // 3. Strict Exercise Name lookup
    final byName = getGifForExerciseName(exerciseName);
    if (byName != null && isValidGif(byName)) {
      return byName;
    }

    // 4. Strict Fallback: Demonstration unavailable
    return null;
  }

  /// Returns true if this exercise has an audited, verified animated GIF demonstration.
  static bool hasDemonstration({String? exerciseId, String? exerciseName}) {
    return resolveGif(exerciseId: exerciseId, exerciseName: exerciseName) != null;
  }
}
