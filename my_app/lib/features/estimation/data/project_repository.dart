import '../models/saved_project.dart';
import '../state/estimate_session_store.dart';
import 'project_api_client.dart';

class ProjectRepository {
  final ProjectApiClient _apiClient;

  ProjectRepository({ProjectApiClient? apiClient})
    : _apiClient = apiClient ?? ProjectApiClient();

  Future<SavedProjectDetail> createProject({
    required EstimateFlow flow,
    required String projectName,
    required String projectLocation,
  }) {
    return _apiClient.createProject(
      context: _contextForFlow(flow),
      projectName: projectName,
      projectLocation: projectLocation,
    );
  }

  Future<List<SavedProjectSummary>> fetchRecentProjects({
    required EstimateFlow flow,
    int limit = 30,
  }) {
    return _apiClient.fetchRecentProjects(
      context: _contextForFlow(flow),
      limit: limit,
    );
  }

  Future<SavedProjectDetail> fetchProject(String projectId) {
    return _apiClient.fetchProject(projectId);
  }

  Future<void> syncSession(EstimateSessionStore session) async {
    final String? projectId = session.projectId;
    if (projectId == null || projectId.isEmpty) {
      return;
    }
    await _apiClient.saveProjectWindows(
      projectId: projectId,
      windows: session.items,
    );
  }

  String _contextForFlow(EstimateFlow flow) {
    return flow == EstimateFlow.fabrication ? 'fabrication' : 'estimation';
  }
}
