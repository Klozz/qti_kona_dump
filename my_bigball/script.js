(function(){
    //var animData = FaceUnity.LoadAnimationData("anim.json", "anim_dq.bin", "anim_local.bin");
    var animData = FaceUnity.LoadAnimationDataForAnimator("anim.json", "anim_translate.bin", "anim_rotate.bin", "anim_scale.bin", "anim_expression.bin");

    var boneMapStr = FaceUnity.ReadFromCurrentItem("boneMap.json");
    var boneMap = JSON.parse(boneMapStr ||"{}");

    var globals = JSON.parse(FaceUnity.ReadFromCurrentItem("globals.json")||"{}");

    return {
        animData: animData,
        globals: globals,
        boneMapStr: boneMapStr,
        boneMap: boneMap,
        Render:function(){},
        name:"animation"
    };
})()
