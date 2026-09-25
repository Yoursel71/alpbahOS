// Editör menüsü: "ULTRAKILL > Sahneyi Oluştur ve Oyna" Assets/ULTRAKILL/ULTRAKILL.unity sahnesini açar
// (yoksa boş bir sahneye UKGame ekleyip oluşturur), Build Settings'e ekler ve Play'e basar.
// (Menü kullanılmasa da olur: ULTRAKILL sahnesinde ya da kaydedilmemiş boş sahnede Play'e basınca oyun kendiliğinden kurulur.)
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace UK.EditorTools
{
    public static class UKMenu
    {
        const string ScenePath = "Assets/ULTRAKILL/ULTRAKILL.unity";

        [MenuItem("ULTRAKILL/Sahneyi Oluştur ve Oyna %#u")]
        static void CreateAndPlay()
        {
            if (EditorApplication.isPlaying) return;
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            if (System.IO.File.Exists(ScenePath)) EditorSceneManager.OpenScene(ScenePath);
            else
            {
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                new GameObject("ULTRAKILL").AddComponent<UKGame>();
                EditorSceneManager.SaveScene(scene, ScenePath);
            }
            var list = new List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
            if (!list.Exists(s => s.path == ScenePath))
            {
                list.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
                EditorBuildSettings.scenes = list.ToArray();
            }
            EditorApplication.isPlaying = true;
        }

        [MenuItem("ULTRAKILL/Oyna")]
        static void Play()
        {
            if (EditorApplication.isPlaying) return;
            if (System.IO.File.Exists(ScenePath))
            {
                if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
                EditorSceneManager.OpenScene(ScenePath);
            }
            EditorApplication.isPlaying = true;
        }

        [MenuItem("ULTRAKILL/Ayarları Sıfırla")]
        static void ResetPrefs()
        {
            foreach (var k in new[] { "uk.sens", "uk.fov", "uk.vol", "uk.shake", "uk.assist", "uk.invy", "uk.diff", "uk.best.0-1" }) PlayerPrefs.DeleteKey(k);
            PlayerPrefs.Save();
            Debug.Log("ULTRAKILL: ayarlar ve en iyi derece sıfırlandı.");
        }
    }
}
